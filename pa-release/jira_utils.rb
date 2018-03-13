require 'platform-ci-utils'

FILTER_ENTRIES = {
  "puppet-agent" => "5.5.0",
  "FACT" => "3.11.0",
  "MCO" => "2.12.0",
#  "HI" => "3.4.2",
#  "cpp-pcp-client" => "1.5.5",
#  "whereami" => "0.2.0",
  "PUP" => "5.5.0",
  "pxp-agent" => "1.9.0",
  "LTH" => "1.4.0"
}
RELEASE_NOTES = "customfield_11100"
RELEASE_NOTES_SUMMARY = "customfield_12100"

# These tickets have already been processed. Add these as you go.
IGNORE_TICKETS = [
]


@jira_client = PlatformCIUtils::Jira.new(ENV['JIRA_USER'], ENV['JIRA_PASSWORD'], ENV['JIRA_INSTANCE']).instance_variable_get('@jira_client')

def create_jql_filter(filter_entries)
  jql_filter = 'fixVersion in ('
  filter_entries.each do |project, version|
    jql_filter += "'#{project} #{version}', "
  end
  jql_filter = jql_filter.chomp(", ") + ")"

  return jql_filter
end

# Uses the above created filter
def find_tickets_for_release(filter_entries, options = {})
  options[:ignore_tickets] ||= []
  options[:ignore_states] ||= []
  jql_filter = create_jql_filter(filter_entries)
  @jira_client.Issue.jql(
    jql_filter,
    max_results: -1
  ).reject { |ticket_obj| options[:ignore_tickets].include?(ticket_obj.key) }
   .reject { |ticket_obj| options[:ignore_states].include?(ticket_obj.fields['status']['name']) }
   .select do |ticket_obj|
     next true unless options[:only_states]
     options[:only_states].include?(ticket_obj.fields['status']['name'])
   end
end

def create_state_map(tickets)
  tickets.inject({}) do |tickets_in, ticket|
    state = ticket.fields['status']['name']
    tickets_in[state] ||= []
    tickets_in[state].push(ticket)
    tickets_in
  end
end

def map_values(hash)
  hash.map { |k, v| [k, yield(v)] }.to_h
end

# fmap
def transform_tickets(state_map, &block)
  f = proc do |tickets|
    tickets.map { |ticket| block.call(ticket) }
  end
  map_values(state_map) { |tickets| f.call(tickets) }
end

def extract_ticket_keys(state_map)
  transform_tickets(state_map) { |ticket_obj| ticket_obj.key }
end

def organize_tickets_for_release(filter_entries, options = {})
  create_state_map(find_tickets_for_release(filter_entries, options))
end

def organize_unresolved_tickets(filter_entries, options = {})
  organize_tickets_for_release(
    filter_entries,
    ignore_tickets: options[:ignore_tickets],
    ignore_states: [ "Resolved", "Closed" ]
  )
end

def organize_resolved_tickets(filter_entries, options = {})
  organize_tickets_for_release(
    filter_entries,
    ignore_tickets: options[:ignore_tickets],
    only_states: [ "Resolved", "Closed" ]
  )
end

def has_release_notes?(ticket_obj)
  release_notes_field = ticket_obj.fields[RELEASE_NOTES]
  return true if release_notes_field && release_notes_field['value'] == "Not Needed"
  ticket_obj.fields[RELEASE_NOTES_SUMMARY]
end

def organize_tickets_that_need_release_notes(filter_entries, options = {})
  tickets_needing_release_notes = find_tickets_for_release(
    filter_entries,
    ignore_tickets: options[:ignore_tickets],
    only_states: ['Resolved', 'Closed']
  ).reject do |ticket|
    has_release_notes?(ticket) 
  end

  create_state_map(tickets_needing_release_notes)
end

# Includes:
#   (0) Summary
#   (1) Involved Devs (only their JIRA username). Ordered by "Assignee" => "Watchers" => "Reporter"
#   (2) State
#   (3) Ticket Comments (in chronological order)
#         "User", "Body"
# and optional fields can also be included
def get_ticket_info(ticket_obj, options = {})
  optional_fields = [
    :comments,
    :release_notes,
    :description
  ]
  optional_fields.each { |field| options[field] = false unless options.key?(field) }

  # Get the summary
  summary = ticket_obj.fields['summary']

  # Get the involved devs
  involved_devs = {}
  involved_devs[:assignee] = (ticket_obj.assignee.key) if ticket_obj.assignee
  involved_devs[:watchers] = ticket_obj.watchers.all.map(&:key) if ticket_obj.watchers
  involved_devs[:reporter] = (ticket_obj.reporter.key) if ticket_obj.reporter

  # Get the ticket state
  state = ticket_obj.fields['status']['name'] 

  return_hash = {}
  return_hash[:state] = state
  return_hash[:summary] = summary
  return_hash[:involved_devs] = involved_devs

  if options[:release_notes] and has_release_notes?(ticket_obj)
    return_hash[:release_notes] = ticket_obj.fields[RELEASE_NOTES]['value']
    return_hash[:release_notes_summary] = ticket_obj.fields[RELEASE_NOTES_SUMMARY] if ticket_obj.fields[RELEASE_NOTES_SUMMARY]
  end

  return_hash[:description] = ticket_obj.fields['description'] if options[:description]

  # Get the ticket comments
  return_hash[:comments] = ticket_obj.comments.map do |comment|
    { :author => comment.author['key'], :body => comment.body }
  end if options[:comments]

  return_hash
end

def get_ticket_infos(ticket_objs, options = {})
  ticket_objs.map do |ticket_obj|
    [ticket_obj.key, get_ticket_info(ticket_obj, options)]
  end.to_h
end

TICKET_REGEX=/(\w+)-\d+/

def parse_project(ticket)
  # Throw exception here when actually implementing this stuff.
  TICKET_REGEX.match(ticket)[1]
end

def add_release_notes(ticket, release_notes, release_notes_summary = nil)
  ticket_obj = @jira_client.Issue.find(ticket)
  return if has_release_notes?(ticket_obj)

  put_req = {
    "fields" => {
      RELEASE_NOTES => release_notes
    }
  }
  if release_notes != "Not Needed" and not release_notes_summary
    raise "Must provide the release notes summary!"
  end
  put_req["fields"][RELEASE_NOTES_SUMMARY] = release_notes_summary

  ticket_obj.save!(put_req)
end

# Use @jira_client.Project.find(<project_name>).versions to get a list of all the
# available fix versions for a ticket. Can query with the name in the version file

# This code will return the names of the fix versions as an array.
def get_fix_versions(ticket)
  @jira_client.Issue.find(ticket).fields['fixVersions'].map do |version|
    version['name']
  end.uniq
end

# This code deletes the passed-in fix version from the ticket
def delete_fix_version(ticket, version)
  ticket_obj = @jira_client.Issue.find(ticket)
  cur_fix_versions = ticket_obj.fields['fixVersions']
  # If our fix version is not there, no-op. Otherwise, we will be sending out
  # unnecessary e-mail notifications.
  return true unless cur_fix_versions.find { |fix_version| fix_version['name'] == version }

  ticket_obj.save!({
    "fields" => {
      "fixVersions" => cur_fix_versions.reject { |fix_version| fix_version['name'] == version }
    }
  })
end

# This code adds the specified fix version to the JIRA ticket.
def add_fix_version(ticket, version)
  ticket_obj = @jira_client.Issue.find(ticket)
  cur_fix_versions = ticket_obj.fields['fixVersions']
  # If our fix version is there, no-op. Otherwise, we will be sending out
  # unnecessary e-mail notifications.
  return true if cur_fix_versions.find { |fix_version| fix_version['name'] == version }

  project = parse_project(ticket)
  fix_version_obj = @jira_client.Project.find(project).versions.find do |fix_version|
    fix_version.name == version
  end

  raise "Fix version #{version} does not exist in the project #{project}!" unless fix_version_obj

  ticket_obj.save!({
    "fields" => {
      "fixVersions" => cur_fix_versions.push(fix_version_obj.attrs)
    }
  })
end
