# Redmine Stats Plugin

A comprehensive statistics and reporting plugin for Redmine 6.0+ that provides detailed analytics about user contributions and issues.

## Features

- **Project Dashboard**: Overview of project health, issue statistics, and top contributors
- **User Reports**: Detailed statistics about user contributions, including issues created, assigned, and closed
- **Project Reports**: Analytics about project activity, trends, and workload distribution
- **Issue Reports**: Analysis of issue resolution times and other metrics
- **Interactive Charts**: Visual representation of all statistics using modern charts
- **Contribution Scores**: Algorithm to evaluate user contributions based on various metrics
- **Historical Data**: Track project health and performance over time

## Requirements

- Redmine 6.0.0 or higher
- MySQL/MariaDB, PostgreSQL, or SQLite
- Modern web browser with JavaScript enabled

## Installation

1. Clone or download this repository into your Redmine plugins directory:
   ```
   cd /path/to/redmine/plugins
   git clone https://github.com/redmine/redmine_stats.git
   ```

2. Run the database migrations:
   ```
   cd /path/to/redmine
   bundle exec rake redmine:plugins:migrate RAILS_ENV=production
   ```

3. Restart your Redmine application server.

## Configuration

1. Go to **Administration > Plugins > Redmine Stats Plugin > Configure**
2. Set your preferred defaults for charts, periods, and other options
3. Enable the "Stats" module in your project settings

## Usage

1. Navigate to a project where the "Stats" module is enabled
2. Click on the "Stats" tab in the project menu
3. Explore the various reports and statistics

## License

This plugin is licensed under the MIT License.

## Support

If you encounter any issues or have questions, please create an issue on the [GitHub repository](https://github.com/redmine/redmine_stats/issues).

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. 