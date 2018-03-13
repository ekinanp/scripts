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
    tickets_in[state].push(ticket.key)
    tickets_in
  end
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

def organize_tickets_that_need_release_notes(filter_entries, options = {})
  tickets_needing_release_notes = find_tickets_for_release(
    filter_entries,
    ignore_tickets: options[:ignore_tickets],
    only_states: ['Resolved', 'Closed']
  ).select do |ticket|
    release_notes_field = ticket.fields[RELEASE_NOTES]
    next false  if release_notes_field && release_notes_field['value'] == "Not Needed"
    not ticket.fields[RELEASE_NOTES_SUMMARY]
  end

  create_state_map(tickets_needing_release_notes)
end

# Includes:
#   (1) Involved Devs (only their JIRA username). Ordered by "Assignee" => "Watchers" => "Reporter"
#   (2) State
#   (3) Ticket Comments (in chronological order)
#         "User", "Body"
def get_ticket_info(ticket, options = {})
  options[:include_comments] = false unless options.key?(:include_comments)

  ticket_obj = @jira_client.Issue.find(ticket)

  # Get the involved devs first
  involved_devs = {}
  involved_devs[:assignee] = (ticket_obj.assignee.key) if ticket_obj.assignee
  involved_devs[:watchers] = ticket_obj.watchers.all.map(&:key) if ticket_obj.watchers
  involved_devs[:reporter] = (ticket_obj.reporter.key) if ticket_obj.reporter

  # Get the ticket state
  state = ticket_obj.fields['status']['name'] 

  return_hash = {}
  return_hash[:state] = state
  return_hash[:involved_devs] = involved_devs

  return return_hash unless options[:include_comments]

  # Get the ticket comments
  return_hash[:comments] = ticket_obj.comments.map do |comment|
    { :author => comment.author['key'], :body => comment.body }
  end

  return_hash
end
