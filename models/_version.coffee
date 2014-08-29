@VERSION = 110

global = @

class @VersionedInstance extends StamperInstance
  __name__: 'VersionedInstance'
  
  @fields
    version: VERSION
    
  @register
    getAllFor: @static (query, password, collection) ->
      if Meteor.isServer and password is PASSWORD
        debug "getAllFor", collection, query
        cursor = global[collection].find query
        r = cursor.fetch()
        debug r
        r
