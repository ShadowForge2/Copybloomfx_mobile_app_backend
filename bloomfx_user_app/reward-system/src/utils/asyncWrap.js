/**
 * Wrap async route handlers to catch promise rejections.
 */
function asyncWrap(fn) {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}

module.exports = asyncWrap;
