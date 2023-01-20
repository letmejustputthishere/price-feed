import Blob "mo:base/Blob";
import Text "mo:base/Text";
import Types "types";

module {
  public func decodeBody(response : Types.http_response) : Types.DecodedHttpResponse {
    switch (Text.decodeUtf8(Blob.fromArray(response.body))) {
      case null { { response with body = "" } };
      case (?decoded) { { response with body = decoded } };
    };
  };
};
