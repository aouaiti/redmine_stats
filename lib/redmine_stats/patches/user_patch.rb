module RedmineStats
  module Patches
    module UserPatch
      def self.included(base)
        base.class_eval do
          # Add methods for user statistics
          
          # Count issues created by the user in a project
          def issues_created_count(project=nil, options={})
            issues = Issue.by_author(id)
            issues = issues.where(project_id: project.id) if project
            
            if options[:from] && options[:to]
              issues = issues.created_between(options[:from], options[:to])
            end
            
            issues.count
          end
          
          # Count issues assigned to the user
          def issues_assigned_count(project=nil, options={})
            issues = Issue.by_assigned_to(id)
            issues = issues.where(project_id: project.id) if project
            
            if options[:from] && options[:to]
              issues = issues.created_between(options[:from], options[:to])
            end
            
            issues.count
          end
          
          # Count closed issues by the user
          def closed_issues_count(project=nil, options={})
            from = options[:from] || (Date.today - 12.months)
            to = options[:to] || Date.today
            
            # Find issues closed by this user through journal entries
            journals = Journal.joins(:details).where(user_id: id)
              .where("journal_details.property = 'attr' AND journal_details.prop_key = 'status_id'")
              .where("journal_details.value IN (?)", IssueStatus.where(is_closed: true).pluck(:id).map(&:to_s))
              .where('journals.created_on BETWEEN ? AND ?', from, to)
            
            if project
              journals = journals.joins(:issue).where(issues: { project_id: project.id })
            end
            
            # Count unique issues
            journals.select("DISTINCT journalized_id").count
          end
          
          # Count comments added by the user
          def comments_count(project=nil, options={})
            from = options[:from] || (Date.today - 12.months)
            to = options[:to] || Date.today
            
            # Find comments added by this user
            journals = Journal.where(user_id: id)
              .where("notes IS NOT NULL AND notes != ''")
              .where('journals.created_on BETWEEN ? AND ?', from, to)
            
            if project
              journals = journals.joins(:issue).where(issues: { project_id: project.id })
            end
            
            journals.count
          end
          
          # Count status updates by user (measure of activity/involvement)
          def status_updates_count(project=nil, options={})
            from = options[:from] || (Date.today - 12.months)
            to = options[:to] || Date.today
            
            # Find status updates made by this user
            journals = Journal.joins(:details).where(user_id: id)
              .where("journal_details.property = 'attr' AND journal_details.prop_key = 'status_id'")
              .where('journals.created_on BETWEEN ? AND ?', from, to)
            
            if project
              journals = journals.joins(:issue).where(issues: { project_id: project.id })
            end
            
            journals.count
          end
          
          # Count on-time resolutions (issues that were resolved before their due date)
          def on_time_resolutions_count(project=nil, options={})
            from = options[:from] || (Date.today - 12.months)
            to = options[:to] || Date.today
            
            # Find closed issues that had a due date and were closed before or on that date
            # First find the journals that closed issues
            closing_journals = Journal.joins(:details).where(user_id: id)
              .where("journal_details.property = 'attr' AND journal_details.prop_key = 'status_id'")
              .where("journal_details.value IN (?)", IssueStatus.where(is_closed: true).pluck(:id).map(&:to_s))
              .where('journals.created_on BETWEEN ? AND ?', from, to)
              
            if project
              closing_journals = closing_journals.joins(:issue).where(issues: { project_id: project.id })
            end
            
            # Count those where closing date is before due date
            count = 0
            closing_journals.each do |journal|
              issue = journal.journalized
              if issue && issue.due_date && journal.created_on.to_date <= issue.due_date
                count += 1
              end
            end
            
            count
          end
          
          # Average resolution time for issues created by the user
          def average_resolution_time(project=nil, options={})
            from = options[:from] || (Date.today - 12.months)
            to = options[:to] || Date.today
            
            # Get closed issues created by this user
            issues = Issue.by_author(id).closed.where('issues.updated_on BETWEEN ? AND ?', from, to)
            issues = issues.where(project_id: project.id) if project
            
            return 0 if issues.count == 0
            
            total_time = 0
            count = 0
            
            issues.each do |issue|
              resolution = issue.resolution_time
              if resolution
                total_time += resolution
                count += 1
              end
            end
            
            count > 0 ? (total_time / count) : 0
          end
          
          # Overall contribution score based on various metrics
          def contribution_score(project=nil, options={})
            created = issues_created_count(project, options)
            assigned = issues_assigned_count(project, options)
            closed = closed_issues_count(project, options)
            comments = comments_count(project, options)
            status_updates = status_updates_count(project, options)
            on_time = on_time_resolutions_count(project, options)
            
            # Enhanced weighted score with more factors
            not_on_time = closed - on_time       # Calculate not-on-time resolutions
            
            # Administrative tasks
            admin_score = (created * 1.0) +       # Creating issues
                          (assigned * 1.0) +      # Being assigned issues
                          (closed * 1.0) +        # Closing issues
                          (comments * 1.0) +      # Making comments
                          (status_updates * 1.0)  # Updating status
            
            # Technical tasks
            tech_score = (on_time * 3.0) +        # On-time resolutions (higher weight)
                         (not_on_time * 1.0)      # Not-on-time resolutions
            
            # Total score
            score = admin_score + tech_score
            
            # Return the final score
            score.round(1)
          end
          
          # Get detailed breakdown of contribution components
          def contribution_details(project=nil, options={})
            created = issues_created_count(project, options)
            assigned = issues_assigned_count(project, options)
            closed = closed_issues_count(project, options)
            comments = comments_count(project, options)
            status_updates = status_updates_count(project, options)
            on_time = on_time_resolutions_count(project, options)
            not_on_time = closed - on_time
            
            # Calculate administrative and technical scores
            administrative = created + assigned + closed + comments + status_updates
            technical = on_time * 3.0 + not_on_time * 1.0
            
            {
              components: {
                administrative: {
                  count: administrative,
                  weight: 1.0,
                  value: administrative,
                  breakdown: {
                    created: created,
                    assigned: assigned,
                    closed: closed,
                    comments: comments,
                    status_updates: status_updates
                  }
                },
                technical: {
                  count: on_time + not_on_time,
                  weight: 'variable',
                  value: technical,
                  breakdown: {
                    on_time: {
                      count: on_time,
                      weight: 3.0,
                      value: on_time * 3.0
                    },
                    not_on_time: {
                      count: not_on_time,
                      weight: 1.0,
                      value: not_on_time * 1.0
                    }
                  }
                }
              },
              original_components: {
                created: {
                  count: created,
                  weight: 1.0,
                  value: created * 1.0
                },
                assigned: {
                  count: assigned,
                  weight: 1.0,
                  value: assigned * 1.0
                },
                closed: {
                  count: closed,
                  weight: 1.0,
                  value: closed * 1.0
                },
                comments: {
                  count: comments,
                  weight: 1.0,
                  value: comments * 1.0
                },
                status_updates: {
                  count: status_updates,
                  weight: 1.0,
                  value: status_updates * 1.0
                },
                on_time: {
                  count: on_time,
                  weight: 3.0,
                  value: on_time * 3.0
                },
                not_on_time: {
                  count: not_on_time,
                  weight: 1.0,
                  value: not_on_time * 1.0
                }
              },
              total: administrative + technical
            }
          end
        end
      end
    end
  end
end

unless User.included_modules.include?(RedmineStats::Patches::UserPatch)
  User.send(:include, RedmineStats::Patches::UserPatch)
end 