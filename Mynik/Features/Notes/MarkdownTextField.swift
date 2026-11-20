import SwiftUI

/// Campo de texto que mostra o Markdown formatado quando não está a ser editado.
///
/// O campo fica sempre por baixo (transparente), por isso tocar no texto
/// formatado começa logo a editar.
struct MarkdownTextField: View {
    let placeholder: String
    @Binding var text: String
    var axis: Axis = .horizontal
    var focus: FocusState<String?>.Binding
    let id: String
    var onSubmit: (() -> Void)?

    private var isEditing: Bool {
        focus.wrappedValue == id || text.isEmpty
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextField(placeholder, text: $text, axis: axis)
                .focused(focus, equals: id)
                .onSubmit { onSubmit?() }
                .opacity(isEditing ? 1 : 0)

            if !isEditing {
                Text(NoteMarkdown.attributed(text))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .allowsHitTesting(false)
            }
        }
    }
}
