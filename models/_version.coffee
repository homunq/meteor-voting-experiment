@VERSION = 0.98

global = @

class @VersionedInstance extends StamperInstance
  __name__: 'VersionedInstance'
  
  @fields
    version: VERSION
    
  @register
    getAllFor: @static (query, password, collection) ->
      if Meteor.isServer and password is PASSWORD
        slog "getAllFor", collection, query
        cursor = global[collection].find query
        r = cursor.fetch()
        slog r
        r
