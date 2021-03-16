# JiraPlot

A command-line tool to generate graphs from Jira issues, showing which issues block which, which issues are done, and which are planned on future sprints. Created to be compatible with a few personal and professional projects worked on by me, but available for anyone to tweak if needed and use with their own projects.

## Installation

1. Build using the Swift Package Manager with `swift build`
1. Copy the executable to a location in your path, e.g. `cp .build/debug/JiraPlot /usr/local/bin/jiraPlot`

## Usage

1. On Jira, create a filter that shows only the issues that should appear in the graph
1. Switch to List View, if needed
1. Make sure the Columns include the issue's Key, Labels, Linked Issues, Sprint, Status and Summary
1. Click `Export → Export Excel CSV (current fields)`
1. Run `jiraPlot jira.csv` (assuming the downloaded file is called `jira.csv`)
