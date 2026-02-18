class_name FKGlobalSignals

## Some Node types (like TextEdit) don't emit their text_changed signals when
## their contents are changed through custom user scripts. Thus, we
## have this to compensate.
signal text_changed(prev_text: String, new_text: String, text_holder: Variant)
