I need to implement complex drag & drop functionality for the files and folders in the fima application.
Do me a complex multi-step plan to implement this functionality.

## Description

### Drag & Drop in the fima application

#### Multi-item drag & drop
When usere will select multiple files or folders with space key and then he press and hold mouse button on one of these selected items, the items will be visually grouped together that way, that the icons and names will be still readable. The group will be draggable and when user will hover with this group over some folder in the same panel or over the opposite panel, the folder will be highlighted and when user will drop this group to this folder, all selected items will be moved to this folder. User can drop the group to the blank space of the opposite panel too. In this case the items will be moved to the root folder of the opposite panel. Both panels will be refreshed after the drop.

#### Single-item drag & drop
The same functionality as multi-item, but for the any focused item. 

### Drag & Drop outside of the application

#### Dop files to the fima application
When user will drag files from some other application (like Finder, Dolphin, Windows Explorer) to the fima application, the files will be moved to the current folder of the panel which is user hovering over. Or if user will hover the dragged file over some folder in the fima panel, the files will be moved to this folder.

#### Drag files from the fima application to some other application
When user will drag files from the fima application to some other application, do standard operation for the current platform.

## Notes
Keep in mind that the application is multiplatform and all platform (Linux, MacOS and Windows) have to be supported.

## Libraries
You can use this package for drag and drop functionality: https://pub.dev/packages/super_drag_and_drop