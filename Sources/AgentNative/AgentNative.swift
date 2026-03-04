import ArgumentParser

@main
struct AgentNative: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "agent-native",
        abstract:
            "Control macOS native apps via the Accessibility tree.",
        discussion: """
            Inspired by agent-browser (https://github.com/vercel-labs/agent-browser).
            Uses macOS Accessibility APIs to give AI agents structured control
            over native applications.

            Workflow:
              1. agent-native open "System Settings"
              2. agent-native snapshot "System Settings" -i
              3. agent-native click @n5
              4. agent-native fill @n3 "search query"
            """,
        version: "0.1.2",
        subcommands: [
            AppsCommand.self,
            OpenCommand.self,
            ScreenshotCommand.self,
            SnapshotCommand.self,
            TreeCommand.self,
            FindCommand.self,
            InspectCommand.self,
            GetCommand.self,
            IsCommand.self,
            ClickCommand.self,
            FillCommand.self,
            TypeCommand.self,
            KeyCommand.self,
            PasteCommand.self,
            SelectCommand.self,
            CheckCommand.self,
            UncheckCommand.self,
            FocusCommand.self,
            HoverCommand.self,
            ActionCommand.self,
            WaitCommand.self,
        ],
        defaultSubcommand: nil
    )
}
