"use strict";

exports.fetchImpl = function (requestInfo) {
  return function (url) {
    return function () {
      return fetch(url, requestInfo);
    };
  };
};

exports.simpleFetchGetImpl = function (url) {
  return function () {
    return fetch(url);
  };
};

exports.extractJsonImpl = function (response) {
  return function () {
    return response.json();
  };
};

exports.fetchRequestInfo = function (method) {
  return {
    method,
  };
};
