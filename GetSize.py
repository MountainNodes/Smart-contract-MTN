from fileinput import filename
import json
from glob import glob


def computeByteCodeSizeInKiB (byteCode) :
  # -2 to remove 0x from the beginning of the string
  # /2 because one byte consists of two hexadecimal values
  # /1024 to convert to size from byte to kibibytes
  return (len(byteCode) - 2) / 2 / 1024


folder = "build/contracts/"

for file in glob(folder+"*.json") : 

    json_file = json.loads(open(file).read())

    filename = file.split("/")[-1].split(".")[0]
    size_file = computeByteCodeSizeInKiB(json_file["deployedBytecode"])
    print(f"{filename} size : {size_file}")

#print(computeByteCodeSizeInKiB(open("EtherStonesByte").read()))