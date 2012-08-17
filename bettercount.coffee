if Meteor.is_client
  Template.election.eid = ->
    Meteor.user()?.eid
  Template.election.user = ->
    Meteor.user()?._id
    
  
   
if Meteor.is_server
  Meteor.startup ->


# code to run on server at startup
