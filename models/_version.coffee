VERSION = 0.95

global = @

class VersionedInstance extends StamperInstance
  @fields
    version: VERSION
    
  @register
    getAllFor: @static (query, password, collection) ->
      if Meteor.isServer and password is PASSWORD
        console.log "getAllFor", collection, query
        cursor = global[collection].find query
        r = cursor.fetch()
        console.log r
        r
