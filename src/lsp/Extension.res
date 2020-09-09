let res = ".res"
let resi = ".resi"

let get = uri => Node.Path.extName(uri)

let isReScript = uri => {
  let ext = get(uri)

  switch (ext == res, ext == resi) {
  | (false, false) => false
  | _ => true
  }
}
