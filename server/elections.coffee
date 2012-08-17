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
    uid = @userId()
    election = Elections.findOne
      _id: eid
    if !election
      throw Meteor.error 404, "no such election"
    if (_.indexOf election.voters, uid) == -1
      Elections.update
        _id: eid
      ,
        $push: 
          voters: uid
      ,
        multi: false
        
      Meteor.users.update
        _id: @userId()
      ,
        $set:
          eid: eid
      ,
        multi: false
