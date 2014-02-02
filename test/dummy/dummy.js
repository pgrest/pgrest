(function(){
var pgrest = require("pgrest");
var context = pgrest.context();

module.exports = function(it) { return it };

module.exports.context = function() {
    return context;
}

module.exports.test = function() {
    return pgrest.pgrest_param_get('auth') === context.config.authkey;
};

}).call(this);
