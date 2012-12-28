
@USERS = Meteor.users

class @User extends VersionedInstance
  collection: Meteor.users
  
  @fields
    username: undefined
    eid: undefined
    watcher: undefined
    step: undefined
    lastStep: undefined
    faction: undefined
    turkSubmitTo: undefined
    workerId: undefined
    assignmentId: undefined
    hitId: undefined
    nonunique: undefined
    _wasntMe: undefined
    _paid: undefined
    
    
  
  @register
    setParams: (params) ->
      if @workerId
        if @workerId is params.workerId
          console.log "(re-adding same workerId, ignored)"
          return
        console.log "You sneaky little thang, using the same browser with several workerIds."
        console.log "I should report you but I won't because you're probably me."
      
      if params.workerId
        nonunique = Meteor.users.findOne
          workerId: @workerId
        @nonunique = false #!! nonunique
        if @_wasntMe or nonunique?._wasntMe
          @_wasntMe = true
          @nonunique = false
        if @nonunique and @eid
          @election().userNonunique @id
            
      @workerId = params.workerId
      @assignmentId = params.assignmentId
      @hitId = params.hitId
      @turkSubmitTo = params.turkSubmitTo
      
      @save =>
        console.log "setParams complete", @
  
    wasntMe: (yesItWas) ->
      console.log "Setting nonunique for testing.", !yesItWas
      wasntUnique = @nonunique
      @nonunique = no
      @_wasntMe = !yesItWas
      if @workerId
        dupeWorkers = Meteor.users.find
          workerId: @workerId
        dupeWorkers = dupeWorkers.fetch()
        for dupeWorker in dupeWorkers
          dupeWorker = new User dupeWorker
          dupeWorker._wasntMe = true
          dupeWorker.save()
      @save()
      if @eid and wasntUnique and (@step >= 2) and Meteor.is_server
        Election.join @eid
    
    setPaid: ->
      @paid = yes
      @save()
      
    serverCentsDue: ->
      @centsDue()
      
        
  election: ->
    new Election Elections.findOne
      _id: @eid
  
  votes: ->
    votes = Votes.find
      voter: @_id
    votes = votes.fetch()
    #console.log "hmmmmmmmmmmmmmmmmmmmmmmmm:", @_id, votes
    _.unique votes, false, (vote) ->
      #console.log "unique vote?", vote
      "#{vote.election} #{vote.stage}"
        
  centsDue: ->
    #console.log "centsDue wtf", @, @votes
    if @_paid
      return 0
    cents = 0
    for vote in @votes()
      #console.log "vote is", vote
      if vote.stage in [2,3]
        outcome = Outcomes.findOne
          election: vote.election
          stage: vote.stage
        #console.log "vote outcome", outcome
        if outcome
          outcome = new Outcome outcome
          cents += outcome.payFactionCents @faction
    cents
                
wasntMe = ->
  (new User Meteor.user()).wasntMe()
