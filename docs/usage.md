# Usage Guide

## Rewind Manager

### Signals
- **`rewind_started`**: Emitted when rewinding begins.
- **`rewind_stopped`**: Emitted when rewinding ends.

### Key Methods
- **`start_rewind()`**: Starts the rewind process.
- **`stop_rewind()`**: Stops the rewind process.
- **`_pause_non_rewindables(pause: bool)`**: Pauses or resumes non-rewindable nodes.

### Example