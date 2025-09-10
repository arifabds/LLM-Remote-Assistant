from google.protobuf import descriptor as _descriptor
from google.protobuf import message as _message
from typing import ClassVar as _ClassVar, Optional as _Optional

DESCRIPTOR: _descriptor.FileDescriptor

class ProcessRequest(_message.Message):
    __slots__ = ("clientId", "messageJson")
    CLIENTID_FIELD_NUMBER: _ClassVar[int]
    MESSAGEJSON_FIELD_NUMBER: _ClassVar[int]
    clientId: str
    messageJson: str
    def __init__(self, clientId: _Optional[str] = ..., messageJson: _Optional[str] = ...) -> None: ...

class ProcessResponse(_message.Message):
    __slots__ = ("status", "message")
    STATUS_FIELD_NUMBER: _ClassVar[int]
    MESSAGE_FIELD_NUMBER: _ClassVar[int]
    status: str
    message: str
    def __init__(self, status: _Optional[str] = ..., message: _Optional[str] = ...) -> None: ...

class ConfirmationRequest(_message.Message):
    __slots__ = ("clientId", "approved", "intent")
    CLIENTID_FIELD_NUMBER: _ClassVar[int]
    APPROVED_FIELD_NUMBER: _ClassVar[int]
    INTENT_FIELD_NUMBER: _ClassVar[int]
    clientId: str
    approved: bool
    intent: str
    def __init__(self, clientId: _Optional[str] = ..., approved: bool = ..., intent: _Optional[str] = ...) -> None: ...

class ConfirmationResponse(_message.Message):
    __slots__ = ("status",)
    STATUS_FIELD_NUMBER: _ClassVar[int]
    status: str
    def __init__(self, status: _Optional[str] = ...) -> None: ...
