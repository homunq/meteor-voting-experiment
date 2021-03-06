Meteor.methods
  log: (msgs...) ->
    if Meteor.isServer
      console.log msgs...

global = @
@slog = (msgs...) ->
  if global.slogNum?
    Meteor.call "log", ("    " for i in [0...(global.slogNum+1)]).join(""), msgs..., ""
  else  
    if Meteor.isClient
      console.log msgs...
    Meteor.call "log", "isServer: ", Meteor.isServer, msgs..., ""
