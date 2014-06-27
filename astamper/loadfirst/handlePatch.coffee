if Meteor.isClient
  Handlebars._registerHelper = Handlebars.registerHelper
  Handlebars.registerHelper = (name, helper) ->
    _helper = ->
      slog "calling helper", name
      helper arguments...
    @_registerHelper name, _helper
    
