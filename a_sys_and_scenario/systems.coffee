nobind = (f) ->
  f.nobind = true
  f
  
class System
  constructor: (@name, options) ->
    #NOTE: all methods are bound by default. I'm not sure that this is necessary but I'd sure rather debug the bugs from overdng this than from not doing it.
    for mname, method of options.methods
      if method.nobind
        @[mname] = method
      else
        @[mname] = ->
          method.apply @, arguments
    if Meteor.is_client
      for tPath, tFuncs of options.tFuncs
        template = Template[@name + "_" + tPath]
        for fName, func of funcs
          template[fName] = -> #auto-bind. Unlike the above, this is uncontroversial.
            func.apply @, arguments
  
makeSystems = (systems) ->
  madeSystems = {}
  for sName, sysOpts of systems
    madeSystems[sName] = new System sName, sysOpts
  madeSystems
  
Systems = makeSystems
  approval:
    methods:
      validVote: (numCands, vote) ->
        if vote.length isnt numCands then return false
        if (_(vote).without 0,1) isnt [] then return false
        true
        
      resolveVotes: (numCands, votes) ->
        counts = _.map (_.zip votes...), (cvotes) ->
          _.reduce cvotes, (a,b) ->
            a + b
          , 0
        winners = []
        winningVotes = 0
        for count, cand in counts
          if count > winningVotes
            winners = [cand]
            winningVotes = count
          else if count is winningVotes
            winners.push cand
        winners