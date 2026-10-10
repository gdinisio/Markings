//
//  FocusedValues.swift
//  Markings
//

import Foundation
import SwiftUI

/// The editor of the frontmost document, so menu commands act on the window
/// the user is actually looking at.
struct EditorControllerKey: FocusedValueKey {
    typealias Value = EditorController
}

struct WorkspaceModeKey: FocusedValueKey {
    typealias Value = Binding<WorkspaceMode>
}

struct InspectorVisibleKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

struct ExportActionKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

struct GoToHeadingKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {

    var editorController: EditorController? {
        get { self[EditorControllerKey.self] }
        set { self[EditorControllerKey.self] = newValue }
    }

    var workspaceMode: Binding<WorkspaceMode>? {
        get { self[WorkspaceModeKey.self] }
        set { self[WorkspaceModeKey.self] = newValue }
    }

    var inspectorVisible: Binding<Bool>? {
        get { self[InspectorVisibleKey.self] }
        set { self[InspectorVisibleKey.self] = newValue }
    }

    var htmlExportRequested: Binding<Bool>? {
        get { self[ExportActionKey.self] }
        set { self[ExportActionKey.self] = newValue }
    }

    var goToHeadingRequested: Binding<Bool>? {
        get { self[GoToHeadingKey.self] }
        set { self[GoToHeadingKey.self] = newValue }
    }
}
