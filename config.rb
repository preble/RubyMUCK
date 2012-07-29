#
# RubyMUCK Configuration File
#

# Host to bind to for listening to new connections.
unless defined? HOST
  HOST = '0.0.0.0' # Bind to all interfaces.
end

# The port that will be listened to.
PORT = 8888

# Max number of simultaneousconnections.
MAX_CONNECTIONS = 100

# Directory to watch for and dynamically load code from when updated.
MODULES = './modules'

# DATABASE_FORMAT
# Two database formats are available: YAML and Dump.  While the YAML 
# format is human-readable, it is very, very slow.  Therefore the Dump 
# method is recommended for most users.  They are listed below in order 
# of preference.
#
#  :dump - Fastest.  Safe.
#  :yaml - Very slow.  Safe.
#
DATABASE_FORMAT = :dump
DATABASE_PATH = './db/database.dump'

# DATABASE_SAVE_PERIOD = seconds
# Number of seconds between database saves.  This value is used in the
# database saving tasks.
DATABASE_SAVE_PERIOD = 30*60

# DATABASE_MIRRORED = true/false (recommended true)
# Enables routines that save the full database at regular intervals 
# (DATABASE_SAVE_PERIOD) while never pausing the game in order to perform
# the save.
DATABASE_MIRRORED = true

# Allows stack trace messages to be logged.
ENABLE_DEBUGGING = true
ENABLE_CONSOLE = true

ROOT_PARENT_ROOM = 1
NEW_PLAYER_ROOM = 2
GUEST_ROOM = 3

MUCK_NAME = 'RubyMUCK'
