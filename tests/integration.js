// Generated by CoffeeScript 1.3.3
(function() {
  var assert, should;

  assert = require("assert");

  should = require("should");

  suite("methods", function() {
    var resultt, systemResults, systemm, _results;
    systemResults = {
      plurality: [[0], [4, 2, 3]],
      approval: [[1, 2], [4, 5, 5]],
      GMJ: [[2], [2 / 5, 8 / 3, 11 / 4]],
      IRV: [[2], [[1, 1, 1, 1], 1, [1, 1, 1, 1, 1]]],
      MAV: [[2], [1 / 7, 47 / 17, 23 / 8]],
      condorcet: [[1], [4, 9, 4]],
      borda: [[1], [4, 9, 4]],
      score: [[1], [4, 9, 4]],
      SODA: [[1], [4, 9, 4]]
    };
    _results = [];
    for (systemm in systemResults) {
      resultt = systemResults[systemm];
      _results.push((function(system, result) {
        return test(system, function(done, server) {
          server["eval"](function(system) {
            return emit("result" + system, Methods[system].resolveHonestVotes(Scenarios.chicken));
          }, system);
          return server.once("result" + system, function(r) {
            r.should.eql(result, "system failed:" + system);
            return done();
          });
        });
      })(systemm, resultt));
    }
    return _results;
  });

  suite("integrations", function() {
    return test("two clients", function(done, server, c1, c2) {
      assert.equal(1, 2);
      return done();
    });
  });

}).call(this);
