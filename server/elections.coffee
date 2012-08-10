console.log "loading elections"

Meteor.methods
  new_election: ->
    console.log "new election"
    eid = Elections.insert 
      scenario: 'chicken'
      voters: [@userId()]
      factions: [0]
    
    console.log eid
    console.log @userId()
    
    Meteor.users.update
      _id: @userId()
    ,
      $set:
        eid: eid
    ,
      multi: false
      
  join_election: (eid) ->
    Elections.update
      _id: eid #or type convert????
    ,
      $push: @userId
    ,
      multi: false
      
    Meteor.users.update
      _id: @userId()
    ,
      $set:
        eid: eid
    ,
      multi: false
