module RedmineStats
  module Patches
    module ProjectPatch
      def self.included(base)
        base.class_eval do
          # Project statistics methods
          
          # Get issue counts by status
          def issues_by_status(options={})
            issues = self.issues
            
            if options[:from] && options[:to]
              issues = issues.created_between(options[:from], options[:to])
            end
            
            issues.group(:status).count
          end
          
          # Get issue counts by priority
          def issues_by_priority(options={})
            issues = self.issues
            
            if options[:from] && options[:to]
              issues = issues.created_between(options[:from], options[:to])
            end
            
            issues.group(:priority).count
          end
          
          # Get issue counts by tracker
          def issues_by_tracker(options={})
            issues = self.issues
            
            if options[:from] && options[:to]
              issues = issues.created_between(options[:from], options[:to])
            end
            
            issues.group(:tracker).count
          end
          
          # Get issues created over time
          def issues_created_over_time(options={})
            from = options[:from] || (Date.today - 12.months)
            to = options[:to] || Date.today
            interval = options[:interval] || 'month'
            
            issues = self.issues.created_between(from, to)
            
            case interval
            when 'day'
              issues.group("DATE(issues.created_on)").count
            when 'week'
              # Format the week as "YYYY-WW" for better readability
              result = issues.group("YEARWEEK(issues.created_on, 1)").count
              
              # Convert the YEARWEEK format to a more readable format
              readable_result = {}
              result.each do |yearweek, count|
                year = yearweek.to_s[0..3].to_i
                week = yearweek.to_s[4..5].to_i
                
                # Create a date for the Monday of that week
                date = Date.commercial(year, week, 1) rescue Date.today
                readable_result["#{date.strftime('%Y-%m-%d')}, Week #{week}"] = count
              end
              
              readable_result
            when 'month'
              issues.group("DATE_FORMAT(issues.created_on, '%Y-%m')").count
            end
          end
          
          # Get top contributors based on contribution score
          def top_contributors(limit=10, options={})
            from = options[:from] || (Date.today - 12.months)
            to = options[:to] || Date.today
            
            # Get all users involved with the project
            member_user_ids = members.pluck(:user_id)
            
            # Calculate contribution scores for each user
            scores = User.where(id: member_user_ids).map do |user|
              {
                user: user,
                score: user.contribution_score(self, options),
                issues_created: user.issues_created_count(self, options),
                issues_assigned: user.issues_assigned_count(self, options),
                issues_closed: user.closed_issues_count(self, options)
              }
            end
            
            # Sort by score and limit
            scores.sort_by { |item| -item[:score] }.first(limit)
          end
          
          # Average resolution time for project issues
          def average_resolution_time(options={})
            from = options[:from] || (Date.today - 12.months)
            to = options[:to] || Date.today
            
            # Get closed issues in the time period
            issues = self.issues.closed.where('issues.updated_on BETWEEN ? AND ?', from, to)
            
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
        end
      end
    end
  end
end

unless Project.included_modules.include?(RedmineStats::Patches::ProjectPatch)
  Project.send(:include, RedmineStats::Patches::ProjectPatch)
end 