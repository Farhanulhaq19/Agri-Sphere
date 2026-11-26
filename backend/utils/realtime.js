// Live updates over WebSockets (socket.io). Every logged-in app joins a room named after
// its user id; the server pushes new chat messages and notifications there instantly.
const { Server } = require('socket.io');
const { identify } = require('./identity');

let io = null;

function initRealtime(httpServer) {
  io = new Server(httpServer, { cors: { origin: process.env.CORS_ORIGIN || '*' } });
  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth && socket.handshake.auth.token;
      const me = await identify({ headers: { authorization: token ? 'Bearer ' + token : '' } });
      if (!me || me.invalid || me.demo) return next(new Error('unauthorized'));
      socket.data.me = me;
      next();
    } catch (e) {
      next(new Error('unauthorized'));
    }
  });
  io.on('connection', (socket) => {
    socket.join('user:' + socket.data.me.id);
  });
  return io;
}

// Send an event to one user (all their open devices). Safe to call before init.
function emitTo(userId, event, data) {
  if (io && userId) io.to('user:' + String(userId)).emit(event, data);
}

module.exports = { initRealtime, emitTo };
