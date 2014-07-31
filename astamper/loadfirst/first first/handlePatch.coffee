if no #Meteor.isClient
  Handlebars._registerHelper = Handlebars.registerHelper
  Handlebars.registerHelper = (name, helper) ->
    _helper = ->
      helper arguments...
    @_registerHelper name, _helper
    
