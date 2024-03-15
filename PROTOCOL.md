# The S3P (v0.1)
The Super Simple Scope Protocol allows a digital multimeter to talk to
control software.

## Definitions
* The abbreviation "IP" refers to version 4 or 6 of the Internet Protocol as
described in RFCs 791 and 8200
* The abbreviation "TCP" refers to the Transmission Control Protocol as
described in RFC 793
* The abbreviation "UTF8" refers to the Unicode Transformation Format, UTF-8, as
described in RFC 3629
* The abbreviation "JSON" refers to the JavaScript Object Notation as
described in RFC 8259
* The abbreviation "U32" refers to four bytes, interpreted a big-endian unsigned
integer
* The abbreviation "STR" refers to a U32 encoding the number `n` followed by
`n` bytes that are to be interpreted as UTF8 text
* The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD",
"SHOULD NOT", "RECOMMENDED",  "MAY", and "OPTIONAL" in this document are to be
interpreted as described in RFC 2119.

## The Server/Scope
The computer receiving multimeter data ("Server" or "Scope") accepts connections
on port `14258` over TCP. Scopes MUST support IP version 4 or 6 and SHOULD
support both.

## The Client/Meter
The computer sending multimeter data ("Client" or "Meter") connects to port
`14258` of the Server using TCP. Meters MUST support IP version 4 or 6 and MAY
support both.

## The Handshake
To initiate an S3P connection, the Client first initiates a TCP connection to the
Scope, as described in the previous sections. Then it sends the following
a JSON `dict` encoded in a STR, which contains information about the Meter.
The `dict` contains the following information:

| Key      | Value                                                           |
|----------|-----------------------------------------------------------------|
| `name`   | The name of the Meter                                           |
| `probes` | An `array` containing `dict`s with information about the probes |

The `dict`s contained in `probes` contain the following information about each
"probe" (probes are individual measurements of Meters):

| Key     | Value                                                              |
|---------|--------------------------------------------------------------------|
| `type`  | `time`, `current`, `voltage`, `capacitance`, `resistance`          |
| `res`   | The number of bits of resolution of this probe                     |
| `scale` | The interval in which this probe measures (1 ≘ 3kg ⇒ scale = 3000) |
| `name`  | The name the Meter wants the Scope to use for this probe           |

Negative `res` values indicate a resolution of `-res`, while using signed
integers, instead of unsigned ones.

The `probes` MUST NOT be empty, because at least one `time` probe is REQUIRED.

## The actual packets

After the Handshake, the Meter sends packets of samples to the Scope. Those are
sequences of measurements from every probe. Every probe's resolution is rounded
up to a power of 2 to determine the data type used. All probes are sent as
8, 16, 32 or 64 bit big-endian integers.
