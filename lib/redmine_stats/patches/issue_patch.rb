module RedmineStats
  module Patches
    module IssuePatch
      def self.included(base)
        base.class_eval do
          # Add associations if needed

          # Add scopes to help with statistics
          scope :created_between, lambda { |from, to| 
            where('issues.created_on BETWEEN ? AND ?', from, to)
          }
          
          scope :updated_between, lambda { |from, to| 
            where('issues.updated_on BETWEEN ? AND ?', from, to)
          }
          
          # Change to use status_id for closed issues
          # Assuming status_id of 5 is 'Closed' - adjust as needed based on your Redmine configuration
          scope :closed, lambda { 
            where(status_id: IssueStatus.where(is_closed: true).pluck(:id))
          }
          
          scope :closed_between, lambda { |from, to|
            closed.where('issues.updated_on BETWEEN ? AND ?', from, to)
          }
          
          scope :by_author, lambda { |user_id|
            where(author_id: user_id)
          }
          
          scope :by_assigned_to, lambda { |user_id|
            where(assigned_to_id: user_id)
          }
          
          # Add instance methods for stats
          def resolution_time
            return nil unless closed?
            # Get the timestamp when the issue was marked as closed
            closing_journal = journals.joins(:details).where(
              "journal_details.property = 'attr' AND journal_details.prop_key = 'status_id'"
            ).where(
              "journal_details.value IN (?)", IssueStatus.where(is_closed: true).pluck(:id).map(&:to_s)
            ).order('created_on ASC').last
            
            return nil unless closing_journal
            closing_journal.created_on - created_on
          end
          
          def closed?
            status.is_closed if status
          end
        end
      end
    end
  end
end

unless Issue.included_modules.include?(RedmineStats::Patches::IssuePatch)
  Issue.send(:include, RedmineStats::Patches::IssuePatch)
end 