VERSION = 0.94

global = @

class VersionedInstance extends StamperInstance
  @fields
    version: VERSION
    
  @register
    getAllFor: @static (query, password, collection) ->
      if Meteor.is_server and password is PASSWORD
        console.log "getAllFor", collection, query, global[collection]
        cursor = global[collection].find query
        r = cursor.fetch()
        console.log r
        r
