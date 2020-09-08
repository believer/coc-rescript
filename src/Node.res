module Path = {
  @bs.module("path") @bs.splice external resolve: array<string> => string = "resolve"
}
