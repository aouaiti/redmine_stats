class StatsController < ApplicationController
  before_action :find_project_by_project_id, except: [:global_overview]
  before_action :authorize, except: [:global_overview]
  before_action :require_admin, only: [:global_overview]
  
  helper :sort
  include SortHelper
  
  def index
    @from = params[:from].present? ? Date.parse(params[:from]) : (Date.today - 30.days)
    @to = params[:to].present? ? Date.parse(params[:to]) : Date.today
    
    # Get basic project stats
    @open_issues_count = @project.issues.open.count
    @closed_issues_count = @project.issues.closed.count
    @total_issues = @project.issues.count
    
    # Calculate health score
    @health_score = RedmineStats::Utils::StatsCalculator.calculate_project_health_score(@project, from: @from, to: @to)
    
    # Get top contributors
    @top_contributors = @project.top_contributors(10, from: @from, to: @to)
    
    # Issues statistics
    @issues_by_status = @project.issues_by_status(from: @from, to: @to)
    @issues_by_priority = @project.issues_by_priority(from: @from, to: @to)
    @issues_by_tracker = @project.issues_by_tracker(from: @from, to: @to)
    
    # Get issues created over time
    @issues_created_over_time = @project.issues_created_over_time(from: @from, to: @to, interval: params[:interval] || 'month')
    
    # Prepare chart data
    @status_chart_data = RedmineStats::Utils::ChartHelper.generate_pie_chart_data(
      @issues_by_status, 
      { title: l(:label_issues_by_status) }
    ).to_json
    
    @priority_chart_data = RedmineStats::Utils::ChartHelper.generate_pie_chart_data(
      @issues_by_priority, 
      { title: l(:label_issues_by_priority) }
    ).to_json
    
    @tracker_chart_data = RedmineStats::Utils::ChartHelper.generate_pie_chart_data(
      @issues_by_tracker, 
      { title: l(:label_issues_by_tracker) }
    ).to_json
    
    @issues_trend_chart_data = RedmineStats::Utils::ChartHelper.generate_line_chart_data(
      @issues_created_over_time, 
      { 
        title: l(:label_issues_trend),
        dataset_label: l(:label_issues_created)
      }
    ).to_json
  end
  
  def user_reports
    @user = User.find(params[:user_id]) if params[:user_id].present?
    @from = params[:from].present? ? Date.parse(params[:from]) : (Date.today - 30.days)
    @to = params[:to].present? ? Date.parse(params[:to]) : Date.today
    
    # Get all active users in the project if no specific user selected
    @users = @project.members.map(&:user).compact.sort_by(&:name)
    
    if @user
      # Get user statistics
      @issues_created = @user.issues_created_count(@project, from: @from, to: @to)
      @issues_assigned = @user.issues_assigned_count(@project, from: @from, to: @to)
      @issues_closed = @user.closed_issues_count(@project, from: @from, to: @to)
      @contribution_score = @user.contribution_score(@project, from: @from, to: @to)
      @avg_resolution_time = @user.average_resolution_time(@project, from: @from, to: @to)
      
      # Get productivity trend
      @productivity_trend = RedmineStats::Utils::StatsCalculator.calculate_user_productivity_trend(@user, @project, from: @from, to: @to)
      
      # Prepare chart data
      @contribution_chart_data = RedmineStats::Utils::ChartHelper.generate_radar_chart_data(
        {
          l(:label_issues_created) || 'Tickets créés' => @issues_created,
          l(:label_issues_assigned) || 'Tickets assignés' => @issues_assigned,
          l(:label_issues_closed) || 'Tickets fermés' => @issues_closed,
          l(:label_contribution_score) || 'Score de contribution' => (@contribution_score / 10.0).round(1) # Scale down for radar chart
        },
        { 
          title: l(:label_user_contribution) || "Contribution de l'utilisateur",
          dataset_label: @user.name
        }
      ).to_json
      
      @productivity_chart_data = RedmineStats::Utils::ChartHelper.generate_productivity_trend_chart_data(
        @productivity_trend.map { |p| [p[:period], p[:score]] }.to_h,
        { 
          title: l(:label_productivity_trend) || "Tendance de productivité",
          dataset_label: @user.name
        }
      ).to_json
    else
      # Compare all users
      @user_stats = @users.map do |user|
        {
          user: user,
          issues_created: user.issues_created_count(@project, from: @from, to: @to),
          issues_assigned: user.issues_assigned_count(@project, from: @from, to: @to),
          issues_closed: user.closed_issues_count(@project, from: @from, to: @to),
          contribution_score: user.contribution_score(@project, from: @from, to: @to)
        }
      end.sort_by { |stats| -stats[:contribution_score] }
      
      # Prepare comparison chart data
      @users_comparison_chart_data = RedmineStats::Utils::ChartHelper.generate_bar_chart_data(
        @user_stats.map { |stats| [stats[:user].name, stats[:contribution_score]] }.to_h,
        { 
          title: l(:label_user_comparison),
          dataset_label: l(:label_contribution_score)
        }
      ).to_json
    end
  end
  
  def project_reports
    @from = params[:from].present? ? Date.parse(params[:from]) : (Date.today - 30.days)
    @to = params[:to].present? ? Date.parse(params[:to]) : Date.today
    @interval = params[:interval] || 'month'
    
    # Get issue statistics over time
    @issues_created_over_time = @project.issues_created_over_time(from: @from, to: @to, interval: @interval)
    
    # Active periods
    @active_periods = RedmineStats::Utils::StatsCalculator.calculate_active_periods(@project, from: @from, to: @to)
    
    # Historical snapshots
    @snapshots = StatsSnapshot.for_project(@project.id).of_type('project_summary').recent(12)
    
    # Get detailed health score data
    @detailed_health = RedmineStats::Utils::StatsCalculator.calculate_project_health_score(@project, from: @from, to: @to, detailed: true)
    
    # Prepare chart data
    @issues_trend_chart_data = RedmineStats::Utils::ChartHelper.generate_line_chart_data(
      @issues_created_over_time, 
      { 
        title: l(:label_issues_trend),
        dataset_label: l(:label_issues_created)
      }
    ).to_json
    
    @active_hours_chart_data = RedmineStats::Utils::ChartHelper.generate_bar_chart_data(
      @active_periods[:by_hour],
      { 
        title: l(:label_active_hours),
        dataset_label: l(:label_activity_count)
      }
    ).to_json
    
    @active_days_chart_data = RedmineStats::Utils::ChartHelper.generate_bar_chart_data(
      @active_periods[:by_weekday].transform_keys { |d| Date::DAYNAMES[d % 7] },
      { 
        title: l(:label_active_days),
        dataset_label: l(:label_activity_count)
      }
    ).to_json
    
    # Create health components chart data
    @health_components_data = RedmineStats::Utils::ChartHelper.generate_bar_chart_data(
      {
        l(:text_resolution_rate) || "Taux de résolution" => @detailed_health[:components][:resolution_rate],
        l(:text_overdue_issues) || "Gestion des échéances" => 100 - @detailed_health[:components][:overdue_penalty],
        l(:text_resolution_time) || "Temps de résolution" => @detailed_health[:components][:time_factor]
      },
      {
        title: l(:label_health_score) || "Score de santé",
        dataset_label: l(:label_health_components) || "Composantes du score",
        use_value_colors: true,
        max_value: 100
      }
    ).to_json
    
    if @snapshots.any?
      @health_trend_data = RedmineStats::Utils::ChartHelper.generate_line_chart_data(
        @snapshots.map { |s| [s.snapshot_date.to_s, s.data['health_score']] }.to_h,
        { 
          title: l(:label_health_trend),
          dataset_label: l(:label_health_score)
        }
      ).to_json
    end
  end
  
  def issue_reports
    @from = params[:from].present? ? Date.parse(params[:from]) : (Date.today - 30.days)
    @to = params[:to].present? ? Date.parse(params[:to]) : Date.today
    
    # Get average resolution time
    @avg_resolution_time = @project.average_resolution_time(from: @from, to: @to)
    
    # Get issues with longest resolution time
    @longest_issues = @project.issues.closed
      .where('issues.updated_on BETWEEN ? AND ?', @from, @to)
      .to_a # Load all issues into memory
      .select { |issue| issue.resolution_time } # Filter only those with resolution time
      .sort_by { |issue| -issue.resolution_time.to_i } # Sort by resolution time (descending)
      .first(10) # Take top 10
    
    # Get issue creation to resolution time distribution
    issues_with_resolution = @project.issues.closed
      .where('issues.updated_on BETWEEN ? AND ?', @from, @to)
      .to_a
      .select { |issue| issue.resolution_time }
    
    @resolution_distribution = {}
    
    # Group issues by resolution time in days
    issues_with_resolution.each do |issue|
      days = (issue.resolution_time / 86400.0).ceil
      days_group = if days <= 1
        '1 day'
      elsif days <= 3
        '2-3 days'
      elsif days <= 7
        '4-7 days'
      elsif days <= 14
        '8-14 days'
      elsif days <= 30
        '15-30 days'
      else
        '30+ days'
      end
      
      @resolution_distribution[days_group] ||= 0
      @resolution_distribution[days_group] += 1
    end
    
    # Prepare chart data
    @resolution_chart_data = RedmineStats::Utils::ChartHelper.generate_pie_chart_data(
      @resolution_distribution, 
      { title: l(:label_resolution_time_distribution) }
    ).to_json
  end
  
  def global_overview
    @projects = Project.active.has_module(:stats).to_a
    
    @total_issues = Issue.count
    @open_issues = Issue.open.count
    @closed_issues = Issue.closed.count
    
    # Top projects by activity
    @top_projects = @projects.sort_by { |p| -p.issues.count }.first(10)
    
    # Top users globally
    @top_users = User.active.sort_by { |u| -u.issues.count }.first(10)
    
    # Prepare chart data
    @projects_chart_data = RedmineStats::Utils::ChartHelper.generate_bar_chart_data(
      @top_projects.map { |p| [p.name, p.issues.count] }.to_h,
      { 
        title: l(:label_top_projects),
        dataset_label: l(:label_issues_count)
      }
    ).to_json
    
    @users_chart_data = RedmineStats::Utils::ChartHelper.generate_bar_chart_data(
      @top_users.map { |u| [u.name, u.issues.count] }.to_h,
      { 
        title: l(:label_top_users),
        dataset_label: l(:label_issues_count)
      }
    ).to_json
  end
end 