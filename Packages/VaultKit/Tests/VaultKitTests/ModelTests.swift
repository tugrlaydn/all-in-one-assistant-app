import Foundation
import Testing
@testable import VaultKit

@Suite("Models — golden files")
struct GoldenFileTests {
    static let vaultFiles = Fixtures.files(inVault: "Basic")

    @Test(arguments: vaultFiles)
    func everyFixtureFileRoundTripsByteForByte(_ path: String) throws {
        let data = try Fixtures.data("Vaults/Basic/" + path)
        let document = try #require(MarkdownDocument(data: data))
        #expect(document.data == data)
    }

    static let time = Timestamp("2026-09-30T18:00:00+03:00")!

    @Test func taskEdits() throws {
        var task = try #require(TaskItem(document: MarkdownDocument(parsing: Fixtures.text("Vaults/Basic/Tasks/Send invoice.md"))))
        task.setStatus(.done, at: Self.time)
        let checkHours = try #require(task.subtasks.first?.children.first)
        #expect(checkHours.text == "Check hours")
        task.setSubtask(line: checkHours.line, done: true)
        task.addSubtask("Attach timesheet", under: try #require(task.subtasks.first).line)
        task.addSubtask("Email the PDF")
        #expect(task.document.text == (try Fixtures.text("Golden/task-done.md")))
    }

    @Test func weekEdits() throws {
        var week = try #require(HabitWeek(document: MarkdownDocument(parsing: Fixtures.text("Vaults/Basic/Habits/Weeks/2026-W40.md"))))
        week.setPlan(WikiLink("Coding"), for: .knowledge)
        week.appendLog(day: try #require(Day("2026-10-01")), habit: WikiLink("Swimming"), minutes: 30, note: "lake | cold")
        #expect(week.document.text == (try Fixtures.text("Golden/week-logged.md")))
    }

    @Test func noteEdits() throws {
        var note = try #require(Note(document: MarkdownDocument(parsing: Fixtures.text("Vaults/Basic/Notes/Client note.md"))))
        note.setTitle("Client note (ACME)")
        note.setTags(note.tags + ["acme"])
        #expect(note.document.text == (try Fixtures.text("Golden/note-retitled.md")))
    }

    @Test func habitEdits() throws {
        var habit = try #require(Habit(document: MarkdownDocument(parsing: Fixtures.text("Vaults/Basic/Habits/Swimming.md"))))
        habit.setCategory(.mindset)
        habit.setActive(false)
        habit.setDefaultMinutes(60)
        #expect(habit.document.text == (try Fixtures.text("Golden/habit-edited.md")))
    }

    @Test func categoryEdits() throws {
        var categories = try #require(HabitCategories(document: MarkdownDocument(parsing: Fixtures.text("Vaults/Basic/Habits/Categories.md"))))
        categories.setBudget(75, for: .mindset)
        categories.setNudgeTimes([try #require(TimeOfDay("20:00")), try #require(TimeOfDay("07:30"))])
        #expect(categories.document.text == (try Fixtures.text("Golden/categories-budget.md")))
    }
}

@Suite("Models — reading")
struct ModelReadTests {
    func load<T: VaultItem>(_ type: T.Type, _ path: String) throws -> T {
        try #require(T(document: MarkdownDocument(parsing: Fixtures.text("Vaults/Basic/" + path))))
    }

    @Test func task() throws {
        let task = try load(TaskItem.self, "Tasks/Send invoice.md")
        #expect(task.id.description == "01J9K4TASK0000000000000001")
        #expect(task.title == "Send invoice")
        #expect(task.status == .todo)
        #expect(task.scheduled?.description == "2026-09-30")
        #expect(task.due?.description == "2026-10-03")
        #expect(task.horizonDay == task.scheduled)
        #expect(task.doneAt == nil)
        #expect(task.priority == 2)
        #expect(task.estimate?.minutes == 45)
        #expect(task.tags == ["work"])
        #expect(task.parent?.target == "Q4 invoicing")
        #expect(task.links.map(\.target) == ["Client note"])
        #expect(task.created?.description == "2026-09-28T09:12:00+03:00")

        let tree = task.subtasks
        #expect(tree.map(\.text) == ["Draft the PDF", "Get the PO number"])
        #expect(tree[0].children.map(\.text) == ["Check hours"])
        #expect(tree[0].children[0].depth == 1)
        #expect(tree[1].isDone)
        #expect(task.progress == 0.5) // leaves: Check hours (open), Get the PO number (done)
    }

    @Test func note() throws {
        let note = try load(Note.self, "Notes/Antenna notes.md")
        #expect(note.title == "Antenna notes")
        #expect(note.tags == ["rf", "capsule"])
        #expect(note.allTags == ["rf", "capsule", "inline-tag"])
        #expect(note.bodyLinks.map(\.target) == ["Send invoice", "Client note"])
        let blockTags = try load(Note.self, "Notes/Client note.md")
        #expect(blockTags.tags == ["work", "clients"])
    }

    @Test func habitsAndWeeks() throws {
        let swimming = try load(Habit.self, "Habits/Swimming.md")
        #expect(swimming.category == .physical)
        #expect(swimming.isActive)
        #expect(swimming.defaultMinutes == 45)
        #expect(try load(Habit.self, "Habits/Piano.md").isActive) // no `active:` key means active

        let week = try load(HabitWeek.self, "Habits/Weeks/2026-W40.md")
        #expect(week.week.description == "2026-W40")
        #expect(week.plan == [.physical: WikiLink("Swimming"), .creative: WikiLink("Piano")])
        #expect(week.log.map(\.minutes) == [45, 30])
        #expect(week.log[1].note == "scales | arpeggios")
        #expect(week.log[0].habitLink == WikiLink("Swimming"))

        let categories = try #require(HabitCategories(document: MarkdownDocument(parsing: Fixtures.text("Vaults/Basic/Habits/Categories.md"))))
        #expect(categories.budgets == [.physical: 150, .creative: 90, .knowledge: 120, .mindset: 60, .monetizable: 90])
        #expect(categories.nudgeTimes.map(\.description) == ["12:30", "20:00"])
    }

    @Test func wrongTypeOrMissingIdIsRefused() throws {
        let plain = MarkdownDocument(parsing: try Fixtures.text("Vaults/Basic/Notes/Plain note.md"))
        #expect(Note(document: plain) == nil)
        #expect(TaskItem(document: MarkdownDocument(parsing: try Fixtures.text("Vaults/Basic/Notes/Antenna notes.md"))) == nil)
        #expect(Note(document: MarkdownDocument(parsing: "---\ntype: note\nid: nope\n---\n")) == nil)
    }
}

@Suite("Models — new files and edits")
struct ModelWriteTests {
    let id = ULID("01J9K4TASK0000000000000009")!
    let created = Timestamp("2026-10-01T08:00:00+03:00")!

    @Test func newFilesFollowTheFormatKeyOrder() {
        let task = TaskItem.new(
            title: "Call: ACME", id: id, created: created, scheduled: Day("2026-10-02"),
            priority: 1, estimate: Estimate("30m"), tags: ["work"], parent: WikiLink("Q4 invoicing")
        )
        #expect(task.document.text == """
        ---
        id: 01J9K4TASK0000000000000009
        type: task
        title: "Call: ACME"
        status: todo
        created: 2026-10-01T08:00:00+03:00
        updated: 2026-10-01T08:00:00+03:00
        scheduled: 2026-10-02
        priority: 1
        estimate: 30m
        tags: [work]
        parent: "[[Q4 invoicing]]"
        ---

        """)
        #expect(Note.new(title: "Idea", id: id, created: created).document.text == """
        ---
        id: 01J9K4TASK0000000000000009
        type: note
        title: Idea
        created: 2026-10-01T08:00:00+03:00
        updated: 2026-10-01T08:00:00+03:00
        ---

        """)
        #expect(HabitWeek.new(week: ISOWeek("2026-W41")!, id: id).document.text == """
        ---
        id: 01J9K4TASK0000000000000009
        type: habit-week
        week: 2026-W41
        plan:
        ---
        ## Log
        | date | habit | minutes | note |
        |---|---|---|---|

        """)
        #expect(Habit.new(title: "Yoga", category: .physical, defaultMinutes: 20, id: id, created: created).category == .physical)
        #expect(HabitCategories.new(budgets: [.mindset: 60, .physical: 150], nudgeTimes: [TimeOfDay("20:00")!]).document.text == """
        ---
        type: habit-categories
        budget_minutes_per_week:
          physical: 150
          mindset: 60
        nudge_times: ["20:00"]
        ---

        """)
    }

    @Test func statusChangesStampAndClearDoneAt() {
        var task = TaskItem.new(title: "T", id: id, created: created)
        task.setStatus(.done, at: created)
        #expect(task.doneAt == created)
        #expect(task.frontMatter.keys.last == "done_at")
        task.setStatus(.todo, at: created)
        #expect(task.doneAt == nil)
        #expect(task.frontMatter.contains("done_at")) // emptied, not removed: keys are never removed
    }

    @Test func subtasksInATaskWithoutASection() {
        var task = TaskItem.new(title: "T", id: id, created: created, body: "Notes without a newline")
        let line = task.addSubtask("First")
        #expect(task.document.body == "Notes without a newline\n\n## Subtasks\n- [ ] First\n")
        task.addSubtask("Child", under: line)
        task.addSubtask("Second")
        #expect(task.document.body.hasSuffix("## Subtasks\n- [ ] First\n  - [ ] Child\n- [ ] Second\n"))
        #expect(task.subtasks.map(\.text) == ["First", "Second"])
        #expect(task.progress == 0)
    }

    @Test func subtaskIndentationStyleIsKept() {
        let body = "## Subtasks\n* [ ] Tabbed\n\t* [X] child\n\t\t* [ ] grandchild\n## Notes\n- [ ] not a subtask\n"
        var task = TaskItem(document: MarkdownDocument(parsing: "---\nid: \(id)\ntype: task\n---\n" + body))!
        #expect(task.subtasks[0].children[0].children.map(\.text) == ["grandchild"])
        #expect(task.subtasks[0].children[0].isDone)
        task.addSubtask("second child", under: task.subtasks[0].line)
        #expect(task.document.body == "## Subtasks\n* [ ] Tabbed\n\t* [X] child\n\t\t* [ ] grandchild\n\t* [ ] second child\n## Notes\n- [ ] not a subtask\n")
    }

    @Test func weekWithoutALogGetsOne() {
        var week = HabitWeek(document: MarkdownDocument(parsing: "---\nid: \(id)\ntype: habit-week\nweek: 2026-W41\n---\nSome text"))!
        week.appendLog(day: Day("2026-10-05")!, habit: WikiLink("Swimming"), minutes: 40)
        #expect(week.document.body == "Some text\n\n## Log\n| date | habit | minutes | note |\n|---|---|---|---|\n| 2026-10-05 | [[Swimming]] | 40 |  |\n")
        #expect(week.log.map(\.minutes) == [40])
        #expect(week.log[0].note == "")
    }
}
