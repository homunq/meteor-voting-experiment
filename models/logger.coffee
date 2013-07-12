Meteor.methods
  log: (msgs ...) ->
    console.log msgs...

global = @
slog = (msgs ...) ->
  if global.slogNum?
    Meteor.call "log", ("    " for i in [0...(global.slogNum+1)]).join(""), msgs...
  else
    Meteor.call "log", msgs...

 