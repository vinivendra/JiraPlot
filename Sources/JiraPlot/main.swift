import SwiftCSV
import Foundation

class Issue: CustomStringConvertible {
    var key: String
    var blocks: [String]
    var blockedBy: [String]
    var labels: [String]
    var issueType: String
    var sprint: String?
    var status: String
    var summary: String
    
    init(
        key: String,
        blocks: [String],
        blockedBy: [String],
        labels: [String],
        issueType: String,
        sprint: String?,
        status: String,
        summary: String)
    {
        self.key = key
        self.blocks = blocks
        self.blockedBy = blockedBy
        self.labels = labels
        self.issueType = issueType
        self.sprint = sprint
        self.status = status
        self.summary = summary
    }
    
    var description: String {
        return """
        Issue \(key)
            blocks: \(blocks)
            blockedBy: \(blockedBy)
            labels: \(labels)
            issueType: \(issueType)
            sprint: \(sprint ?? "nil")
            status: \(status)
            summary: \(summary)
        """
    }
}


// From a file (with errors)
let csvFilePath = CommandLine.arguments.dropFirst().first!
let epicName = CommandLine.arguments.dropFirst(2).first ?? ""
let pdfFilePath = String(csvFilePath.dropLast(4)) + ".pdf"
let dotFilePath = String(csvFilePath.dropLast(4)) + ".dot"

let fileContents = try String(contentsOfFile: csvFilePath)
var lines = fileContents.split(separator: "\n")
let headers = lines[0].split(separator: ",")
var index = 0
let cleanHeaders = headers.map { (header: Substring) -> String in
    if header.contains("Blocks") {
        index += 1
        return "\(header) \(index)"
    }
    else if header.contains("Labels") {
        index += 1
        return "\(header) \(index)"
    }
    else if header.contains("Sprint") {
        index += 1
        return "\(header) \(index)"
    }
    else {
        return String(header)
    }
}

var cleanLines = lines.map { String($0) }
cleanLines[0] = cleanHeaders.joined(separator: ",")
let cleanContents = cleanLines.joined(separator: "\n")

let csvFile: CSV = try CSV(string: cleanContents)

var issues = csvFile.namedRows.map { row -> Issue in
    var blocksIssueKeys: [String] = []
    var labels: [String] = []
    var sprint: String?
    for (key, value) in row {
        if key.contains("Blocks"), !value.isEmpty {
            blocksIssueKeys.append(value)
        }
        else if key.contains("Labels"), !value.isEmpty {
            labels.append(value)
        }
        else if key.contains("Sprint"), !value.isEmpty {
            sprint = value
        }
    }
    
    return Issue(
        key: row["Issue key"]!,
        blocks: blocksIssueKeys,
        blockedBy: [],
        labels: labels,
        issueType: row["Issue Type"]!,
        sprint: sprint,
        status: row["Status"]!,
        summary: row["Summary"]!)
}

var issuesDict: [String: Issue] = [:]
for issue in issues {
    issuesDict[issue.key] = issue
}

for issue in issues {
    for blocks in issue.blocks {
        issuesDict[blocks]?.blockedBy.append(issue.key)
    }
    
    // Remove blocks for issues out of this epic
    issue.blocks = issue.blocks.compactMap {
        issuesDict[$0] == nil ? nil : $0
    }
}

//for issue in issuesDict {
//    print(issue.value)
//}

var result = """
digraph D {
    graph [ranksep="2"];

    labelloc="t";
    label="\(epicName)";
    fontsize = 30


"""

let blockingAndBlockedIssues = issuesDict.values.filter {
    !$0.blocks.isEmpty || !$0.blockedBy.isEmpty
}

let nonBlockingAndBlockedIssues = issuesDict.values.filter {
    !(!$0.blocks.isEmpty || !$0.blockedBy.isEmpty)
}

let sortedIssues = blockingAndBlockedIssues.sorted(by:
    { a, b in
        if a.key == b.key {
            return a.blocks.count < b.blocks.count
        }
        else {
            return a.key < b.key
        }
    })

for issue in sortedIssues {
    var label = "\(issue.key)"
    
    // Sprint
    let rawSprint = issue.sprint ?? issue.labels.first(where: { $0.hasPrefix("SP_") })
    let sprint: String?
    if let rawSprint = rawSprint {
        if let numberStartIndex = rawSprint.firstIndex(where: { $0.isNumber }) {
            if let numberEndIndex =
                rawSprint[numberStartIndex...].firstIndex(where: { !$0.isNumber })
            {
                // NOW | Sprint 60 | Evolução
                let numberString = rawSprint[numberStartIndex..<numberEndIndex]
                sprint = String(numberString)
            }
            else {
                // SP_60
                let numberString = rawSprint[numberStartIndex...]
                sprint = String(numberString)
            }
        }
        else {
            // NOW | BL Técnico | Evolução
            sprint = nil
        }
    }
    else {
        // Sem sprint
        sprint = nil
    }
    
    if let sprint = sprint {
        label += "\\nSprint \(sprint)"
    }
    
    // Summary
    label += "\\n\(wrapSummary(issue.summary))"
    
    // Key and label
    var nodeMessage = "\t\(issue.key.dropFirst(4)) [shape=box,style=filled,label=\"\(label)\""
    
    // Color
    if issue.status == "Done" || issue.status == "Fechado" {
        nodeMessage += ",fillcolor=\"#008000\",fontcolor=white]"
    }
    else if sprint != nil {
        nodeMessage += ",fillcolor=goldenrod3,fontcolor=white]"
    }
    else {
        nodeMessage += "]"
    }
    
    result += nodeMessage + "\n"
}

func wrapSummary(_ summary: String) -> String {
    let parts = summary.split(separator: "]")
    let tag = parts[0] + "]"
    let description = parts.dropFirst().joined(separator: "]")
    
    let limit = 30
    
    let descriptionParts = description.split(separator: "|")
    var wrappedDescriptionParts = [String]()
    for part in descriptionParts {
        // Clean whitespaces
        var cleanChars: [Character] = part.drop(while: { $0 == " " || $0 == "-" }).reversed()
        cleanChars = cleanChars.drop(while: { $0 == " " || $0 == "-" }).reversed()
        let cleanString = cleanChars.map { String($0) }.joined(separator: "")
        let wrappedString = wrapString(cleanString, withLimit: limit)
        wrappedDescriptionParts.append(wrappedString)
    }
    
    let wrappedDescription = wrappedDescriptionParts.joined(separator: "\\n")
    
    return tag + "\\n\\n" + wrappedDescription
}

func wrapString(_ string: String, withLimit limit: Int) -> String {
    var wrappedDescription = ""
    let words = string.split(separator: " ")
    var currentLineCount = 0
    for word in words {
        currentLineCount += word.count + 1
        if currentLineCount > limit {
            currentLineCount = 0
            wrappedDescription += word + "\\n"
        }
        else {
            wrappedDescription += word + " "
        }
    }
    
    // Drop the last separator
    if wrappedDescription.last == "n" {
        wrappedDescription = String(wrappedDescription.dropLast(2))
    }
    else {
        wrappedDescription = String(wrappedDescription.dropLast())
    }
    
    return wrappedDescription
}

var nonBlockedSummary = "Issues não bloqueadas e não bloqueantes:"
var i = 0
for issue in nonBlockingAndBlockedIssues {
    if i % 3 == 0 {
        nonBlockedSummary += "\\n"
    }
    else {
        nonBlockedSummary += ", "
    }
    nonBlockedSummary += issue.key
    
    i += 1
}

result += "\t0 [shape=box,label=\"\(nonBlockedSummary)\"]\n\n"

for issue in sortedIssues {
    for block in issue.blocks {
        result += "\t\(issue.key.dropFirst(4)) -> \(block.dropFirst(4))\n"
    }
}

result += """

}

"""

try result.write(toFile: dotFilePath, atomically: false, encoding: .utf8)

func runProcess(_ arguments: [String]) {
    print("Running \(arguments.joined(separator: " "))")
    let process = Process()

    process.arguments = arguments
    process.qualityOfService = .userInitiated

    if #available(OSX 10.13, *) {
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        try! process.run()
    }
    else {
        process.launchPath = "/usr/bin/env"
        process.launch()
    }

    while process.isRunning {}
}

runProcess(["dot", "-Tpdf", dotFilePath, "-o", pdfFilePath])
runProcess(["open", pdfFilePath])
