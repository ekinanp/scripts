require 'platform-ci-utils'
require 'pp'

# TODO: Add features to automate epic stuff. Probably need to use grasshopper
# for that.

FILTER_ENTRIES = {
  "puppet-agent" => "5.3.6",
  "FACT" => "3.9.6",
  "MCO" => "2.11.5",
  "HI" => "3.4.3",
#  "cpp-pcp-client" => "1.5.5",
#  "whereami" => "0.1.4",
  "PUP" => "5.3.6",
  "pxp-agent" => "1.8.3",
  "LTH" => "1.2.3"
}
RELEASE_NOTES = "customfield_11100"
RELEASE_NOTES_SUMMARY = "customfield_12100"
TEAM = "customfield_14200"
MAIN_JIRA_INSTANCE = "https://tickets.puppetlabs.com"

@jira_obj = PlatformCIUtils::Jira.new(ENV['JIRA_USER'], ENV['JIRA_PASSWORD'], MAIN_JIRA_INSTANCE)
@jira_client = @jira_obj.instance_variable_get('@jira_client')

def find_ticket_obj(ticket)
  return ticket if ticket.is_a?(JIRA::Resource::Issue)
  @jira_client.Issue.find(ticket)
end

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
    ticket_obj = find_ticket_obj(ticket)
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
  state_map = create_state_map(find_tickets_for_release(filter_entries, options))
  options[:keys_only] ? extract_ticket_keys(state_map) : state_map
end

def organize_unresolved_tickets(filter_entries, options = {})
  options[:ignore_states] ||= []
  options[:ignore_states] += [ "Resolved", "Closed" ]
  organize_tickets_for_release(
    filter_entries,
    options
  )
end

def organize_resolved_tickets(filter_entries, options = {})
  options[:only_states] = [ "Resolved", "Closed" ]
  organize_tickets_for_release(
    filter_entries,
    options
  )
end

def has_release_notes?(ticket)
  ticket_obj = find_ticket_obj(ticket)
  release_notes_field = ticket_obj.fields[RELEASE_NOTES]
  return true if release_notes_field && release_notes_field['value'] == "Not Needed"
  ticket_obj.fields[RELEASE_NOTES_SUMMARY]
end

def organize_tickets_that_need_release_notes(filter_entries, options = {})
  keys_only = options[:keys_only]

  # organize_resolved_tickets should return ticket objects so we override
  # "keys_only" here.
  options[:keys_only] = false
  tickets_needing_release_notes = organize_resolved_tickets(
    filter_entries,
    options
  ).values.flatten.reject do |ticket|
    has_release_notes?(ticket) 
  end
  state_map = create_state_map(tickets_needing_release_notes)

  keys_only ? extract_ticket_keys(state_map) : state_map
end

def to_pst_time(time_str)
  Time.parse(time_str).in_time_zone("Pacific Time (US & Canada)")
end

# Includes:
#   * Summary
#   * Last updated (in PST)
#   * Involved Devs (only their JIRA username). Ordered by "Assignee" => "Watchers" => "Reporter"
#   * State
#   * Ticket Comments (in chronological order)
#         "User", "Body"
# and optional fields can also be included
def get_ticket_info(ticket, options = {})
  optional_fields = [
    :comments,
    :release_notes,
    :description
  ]
  optional_fields.each { |field| options[field] = false unless options.key?(field) }

  ticket_obj = find_ticket_obj(ticket)

  # Get the summary
  summary = ticket_obj.fields['summary']

  # Get the last updated time
  updated = to_pst_time(ticket_obj.updated) 
  # Get the team (if applicable)
  if ticket_obj.fields[TEAM]
    team = ticket_obj.fields[TEAM]['value']
  end

  # Get fix versions
  fix_versions = ticket_obj.fields['fixVersions'].map do |version|
    version['name']
  end.uniq


  # Get the involved devs
  involved_devs = {}
  involved_devs[:assignee] = (ticket_obj.assignee.key) if ticket_obj.assignee
  involved_devs[:watchers] = ticket_obj.watchers.all.map(&:key) if ticket_obj.watchers
  involved_devs[:reporter] = (ticket_obj.reporter.key) if ticket_obj.reporter

  # Get the ticket state
  state = ticket_obj.fields['status']['name'] 

  return_hash = {}
  return_hash[:state] = state
  return_hash[:updated] = updated
  return_hash[:fix_versions] = fix_versions
  return_hash[:summary] = summary
  return_hash[:team] = team
  return_hash[:involved_devs] = involved_devs

  if options[:release_notes] and has_release_notes?(ticket_obj)
    return_hash[:release_notes] = ticket_obj.fields[RELEASE_NOTES]['value']
    return_hash[:release_notes_summary] = ticket_obj.fields[RELEASE_NOTES_SUMMARY] if ticket_obj.fields[RELEASE_NOTES_SUMMARY]
  end

  return_hash[:description] = ticket_obj.fields['description'] if options[:description]

  # Get the ticket comments
  return_hash[:comments] = ticket_obj.comments.map do |comment|
    { :author => comment.author['key'], :updated => to_pst_time(comment.updated), :body => comment.body }
  end if options[:comments]

  return_hash
end

def get_ticket_infos(tickets, options = {})
  tickets.map do |ticket|
    ticket_obj = find_ticket_obj(ticket)
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
      RELEASE_NOTES => { "value" => release_notes }
    }
  }
  if release_notes != "Not Needed" and not release_notes_summary
    raise "Must provide the release notes summary!"
  end
  put_req["fields"][RELEASE_NOTES_SUMMARY] = release_notes_summary if release_notes != "Not Needed"

  ticket_obj.save!(put_req)
end

def add_comment(ticket, body)
  ticket_obj = find_ticket_obj(ticket)
  new_comment = ticket_obj.comments.build
  new_comment.save!(body: body)
end

# Takes a block that modifies the comment body
def edit_comment(ticket, match, &block)
  raise "Must pass in a block to edit the existing comment body!" unless block_given?

  match_re = match.is_a?(Regexp) ? match : Regexp.new(Regexp.escape(match))

  ticket_obj = find_ticket_obj(ticket)
  comment = ticket_obj.comments.find do |comment|
    comment.body =~ match_re
  end
  
  unless comment
    puts("Could find any comments that match the given match. Try again!")
    return
  end

  comment.save!(body: yield(comment.body))
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
  version_re = Regexp.new(Regexp.escape(version))
  ticket_obj = @jira_client.Issue.find(ticket)
  cur_fix_versions = ticket_obj.fields['fixVersions']
  # If our fix version is not there, no-op. Otherwise, we will be sending out
  # unnecessary e-mail notifications.
  return true unless cur_fix_versions.find { |fix_version| fix_version['name'] =~ version_re }

  ticket_obj.save!({
    "fields" => {
      "fixVersions" => cur_fix_versions.reject { |fix_version| fix_version['name'] =~ version_re }
    }
  })
end

# This code adds the specified fix version to the JIRA ticket.
def add_fix_version(ticket, version)
  version_re = Regexp.new(Regexp.escape(version))
  ticket_obj = @jira_client.Issue.find(ticket)
  cur_fix_versions = ticket_obj.fields['fixVersions']
  # If our fix version is there, no-op. Otherwise, we will be sending out
  # unnecessary e-mail notifications.
  return true if cur_fix_versions.find { |fix_version| fix_version['name'] =~ version_re }

  project = parse_project(ticket)
  fix_version_obj = @jira_client.Project.find(project).versions.find do |fix_version|
    fix_version.name =~ version_re
  end

  raise "Fix version #{version} does not exist in the project #{project}!" unless fix_version_obj

  ticket_obj.save!({
    "fields" => {
      "fixVersions" => cur_fix_versions.push(fix_version_obj.attrs)
    }
  })
end
