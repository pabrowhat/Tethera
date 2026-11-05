# Tethera: guide

Tethera is a canvas for notes and lore: notes and worlds are laid out as cards, connected by lines.

## Worlds

- All your worlds live in one folder (the **worlds folder**). You choose it on first launch.
- A world is a separate canvas: its own notes, pictures, types and links.
- The start screen lists your worlds. "Open" opens the selected one, "Create" makes a new one, "Rename" and "Delete" work on worlds in the list. A deleted world goes to the trash and is removed for good after 30 days.
- To return to the start screen from a world, use "☰ Project" → "Main menu", or press **Ctrl+M**.
- On first launch a world called "Example" is created. You can delete it.

## Saving

- **Ctrl+S** saves the open world to its folder.
- A `.tether` file is created only by "Export". Export does not change the world.
- **Ctrl+Q** saves the world and quits. Closing the window also saves the world.

## Notes

- A note is a card on the canvas. Double-click it to open it in the side panel.
- Note text is Markdown with BBCode tags (`[b]`, `[i]`, `[color=...]` and others).
- A link is made by writing `[[Title]]` in the text. The link appears as soon as a note with that title exists.
- `[[Title|Label]]` shows the label instead of the title.
- A manual link (Ctrl+click between cards) does not depend on the text.
- Space + click pins a card to the screen: it moves with the canvas until you unpin it with the same Space + click. A plain click on an empty part of the canvas releases all pinned cards.

## Types

- Each world has the types Character, Event, Place, Faction and Item. You can rename, delete and create your own.
- A type sets the card colour and a set of fields: text, number, date or list.
- You can change a card's colour by hand; that overrides the type colour.
- The type filter dims cards that do not match the selected types. Links stay visible.
- Deleting a type does not delete its notes: they become "without type".

## Pictures

- Add a picture with the "Insert picture" button, or from the "Pictures" menu.
- In text a picture is written as `![description|300](path)`, where `300` is the width in pixels.
- "Remove unused pictures" moves pictures that no note refers to into the trash.
- A picture larger than 8000 × 8000 pixels is not opened.

## Export and import

- "Export" opens a window with checkboxes: the ticked notes go into a `.tether` file. "Export the whole world" ticks everything.
- "Include linked notes" adds notes that the ticked ones link to. You can untick them.
- Opening a `.tether` lets you import into the current world or create a new one. If an id already exists, the note is imported as a copy with a new id.
- Files larger than 2 GB, damaged files or files with suspicious compression are not opened. The world does not change.

## Trash and backups

- Deleted notes can be restored: "Trash" → "Restore from trash".
- "Empty trash now" removes everything in the trash for good and asks first. Backups are not affected.
- A daily backup of the world is made on the first launch of each day. The last 7 are kept.

## Settings

- The settings window opens from "☰ Project" or with **Ctrl+,**.
- Changes apply only when you press "Save". "Cancel" changes nothing.
- Basic: interface language (Auto, English, Русский), grid, line width, default colour, reduced motion.
- Advanced: how many backups to keep, and whether linked notes are included in export by default.
- A language change takes effect after a restart.
