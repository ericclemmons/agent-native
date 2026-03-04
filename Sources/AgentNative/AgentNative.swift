import ArgumentParser

@main
struct AgentNative: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "agent-native",
        abstract:
            "Control macOS native apps via the Accessibility tree.",
        discussion: """
            Inspired by agent-browser by Chris Tate (https://github.com/vercel-labs/agent-browser).
            Uses macOS Accessibility APIs to give AI agents structured control
            over native applications.

            Workflow:
              1. agent-native open "System Settings"
              2. agent-native snapshot "System Settings" -i
              3. agent-native click @n5
              4. agent-native fill @n3 "search query"
            """,
        version: "0.1.5",
        subcommands: [
            ActionCommand.self,
            AppsCommand.self,
            CheckCommand.self,
            ClickCommand.self,
            FillCommand.self,
            FindCommand.self,
            FocusCommand.self,
            GetCommand.self,
            HoverCommand.self,
            InspectCommand.self,
            IsCommand.self,
            JsCommand.self,
            KeyCommand.self,
            OpenCommand.self,
            PasteCommand.self,
            ScreenshotCommand.self,
            SelectCommand.self,
            SnapshotCommand.self,
            TreeCommand.self,
            TypeCommand.self,
            UncheckCommand.self,
            WaitCommand.self,
        ],
        defaultSubcommand: nil
    )
}
