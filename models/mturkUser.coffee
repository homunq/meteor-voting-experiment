
@USERS = Meteor.users

class @MtUser extends VersionedInstance
  __name__: "User"
    
  collection: Meteor.users
  
  _loose: yes
  
  @fields
    username: undefined
    token: undefined
    eid: undefined
    watcher: undefined
    step: undefined
    lastStep: undefined
    faction: undefined
    turkSubmitTo: undefined
    stickyWorkerId: undefined
    workerId: undefined
    assignmentId: undefined
    hitId: undefined
    nonunique: undefined
    _wasntMe: undefined
    _paid: undefined    
    
  
  @register
    setParams: (params) ->
      debug "user.setParams started", params
      if @workerId
        if @workerId is params.workerId
          #debug "(re-adding same workerId, ignored)"
          return
        #debug "You sneaky little thang, using the same browser with several workerIds."
        #debug "I should report you but I won't because you're probably me."
      
      if params.workerId
        likeMe = Meteor.users.findOne
          stickyWorkerId: params.workerId
        @nonunique = (likeMe and (likeMe._id isnt @_id))
        if @_wasntMe or likeMe?._wasntMe
          @_wasntMe = true
          @nonunique = false
        if @nonunique and @eid
          @election().userNonunique @id
            
        @stickyWorkerId = params.workerId
      @workerId = params.workerId
      @assignmentId = params.assignmentId
      @hitId = params.hitId
      @turkSubmitTo = params.turkSubmitTo
      
      @save =>
        debug "setParams complete"
  
    wasntMe: (yesItWas) ->
      #debug "Setting nonunique for testing.", !yesItWas
      wasntUnique = @nonunique
      @nonunique = no
      @_wasntMe = !yesItWas
      if @workerId
        dupeWorkers = Meteor.users.find
          workerId: @workerId
        dupeWorkers = dupeWorkers.fetch()
        for dupeWorker in dupeWorkers
          dupeWorker = new MtUser dupeWorker
          dupeWorker._wasntMe = true
          dupeWorker.save()
      @save()
      if @eid and wasntUnique and (@step >= 2) and Meteor.isServer
        Election.join @eid
    
    setPaid: ->
      @paid = yes
      @save()
      
    serverCentsDue: ->
      @centsDue()
      
    forElection: @static (eid) ->
      election = Elections.findOne
        _id: eid
      #debug "forElection", eid, election?.voters, Meteor.users.findOne({_id:election?.voters[0]})
      if election
        return (Meteor.users.findOne({_id:vid}) for vid in election.voters)
      
        
  election: ->
    new Election Elections.findOne
      _id: @eid
  
  votes: ->
    votes = Votes.find
      voter: @_id
    votes = votes.fetch()
    #debug "hmmmmmmmmmmmmmmmmmmmmmmmm:", @_id, votes
    _.unique votes, false, (vote) ->
      #debug "unique vote?", vote
      "#{vote.election} #{vote.stage}"
        
  centsDue: ->
    #debug "centsDue wtf", @, @votes
    if @_paid
      return 0
    cents = 0
    for vote in @votes()
      #debug "vote is", vote
      if vote.stage in [2,3]
        outcome = Outcomes.findOne
          election: vote.election
          stage: vote.stage
        #debug "vote outcome", outcome
        if outcome
          outcome = new Outcome outcome
          cents += outcome.payFactionCents @faction
    cents
    
@getUser = -> 
  (new MtUser Meteor.user())
                
@wasntMe = ->
  getUser().wasntMe()

if Meteor.isServer
  userFields = {}
  for k, v of MtUser.prototype._fields
    userFields[k] = 1
  debug "server publishing userData!", userFields# server
  Meteor.users.allow
    update: (uid, doc) ->
      debug "updating user", uid, doc
      doc._id is uid
  Meteor.publish "userData", ->
    if @userId
      debug "publishing uid", @userId #, Meteor.users.findOne({_id:@userId}).step
      return Meteor.users.find
        _id: @userId
      ,
        fields: userFields
  
    else
      @ready()
    