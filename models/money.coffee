@$baseRate = 160
@$bonusUnit = 40

if (Handlebars?.registerHelper?) 
  Handlebars.registerHelper "baseRate", ->
    
    accounting.formatMoney($baseRate / 100)
  Handlebars.registerHelper "bonus", (mult) ->
    if _.isNumber(mult)
      mult ?= 3
      return accounting.formatMoney($bonusUnit * mult / 100)
    mult
  Handlebars.registerHelper "minAverage", ->
    accounting.formatMoney(($baseRate + ($bonusUnit * 2 * 12 / 9)) / 100)
  Handlebars.registerHelper "maxAverage", ->
    accounting.formatMoney(($baseRate + ($bonusUnit * 2 * 16 / 9)) / 100)
  Handlebars.registerHelper "maxPay", ->
    accounting.formatMoney(($baseRate + ($bonusUnit * 2 * 3)) / 100)
  Handlebars.registerHelper "formatCents", (cents) ->
    accounting.formatMoney(cents / 100)
  Handlebars.registerHelper "centsDue", ->
    centsDue = Session.get "centsDue"
    if centsDue
      return centsDue
    user = new MtUser Meteor.user()
    user.serverCentsDue (error, result) ->
      Session.set "centsDue", result
    user.centsDue()
