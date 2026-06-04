export type CleanUpFunction = (obj: any) -> ()
export type Constructable<T, A...> = { new: (A...) -> T } | (A...) -> T

type ConnectionLike = {
	Connected: boolean,
	Disconnect: (self: ConnectionLike) -> (),
}

export type SignalLike<T...> = {
	Fire: (self: SignalLike<T...>, T...) -> (),
	Connect: (self: SignalLike<T...>, Callback: (T...) -> ()) -> ConnectionLike,
	Wait: (self: SignalLike<T...>) -> T...,
	Once: (self: SignalLike<T...>, Callback: (T...) -> ()) -> ConnectionLike,
	Destroy: (self: SignalLike<T...>) -> (),
}

export type Cleanable =
	Instance
	| SignalLike<...any>
	| ConnectionLike
	| thread
	| { [string]: any }
	| RBXScriptConnection
	| (...any) -> ...any

export type CleanEntry = {
	Object: Cleanable,
	CleanUpFunction: CleanUpFunction,
}

type PublicAttributes = {
	read OnClean: SignalLike<...any>,
}

type PrivateAttributes = {
	_isCleaning: boolean,
	_isDestroyed: boolean,
	_CleanEntries: { CleanEntry },
}

export type PublicMethods<self> = {
	read Add: <T>(self: self, cleanable: Cleanable & T, cleanUpMethod: string?) -> T,
	read Clone: <T>(self: self, instance: Instance & T) -> T,
	read Extend: (self: self) -> PublicMethods<self> & PublicAttributes,
	read Construct: <T, A...>(self: self, Class: Constructable<T, A...>, cleanUpMethod: string?, A...) -> T,
	read Constructer: <T, A...>(self: self, Class: Constructable<T, A...>, cleanUpMethod: string?) -> (A...) -> T,
	read Remove: (self: self, cleanable: Cleanable) -> (),
	read Pop: (self: self, cleanable: Cleanable) -> (),
	read Connect: <T...>(
		self: self,
		signal: SignalLike<T...> | RBXScriptSignal,
		callback: (T...) -> ()
	) -> ConnectionLike,
	read Once: <T...>(self: self, signal: SignalLike<T...> | RBXScriptSignal, callback: (T...) -> ()) -> ConnectionLike,
	read Attach: (self: self, instance: Instance) -> (),
	read Clean: (self: self) -> (),
	read Destroy: (self: self) -> (),
}

export type PrivateMethods<T> = {
	read __CheckIfCleaning: (self: T, methodName: string) -> (),
	read __FindObjectIndex: (self: T, obj: Cleanable) -> number?,
	read __FindAndCleanObject: (self: T, obj: Cleanable) -> boolean,
}

export type CleanerObject = PublicMethods<CleanerObject> & PublicAttributes
export type CleanerInternal =
	PrivateAttributes
	& PrivateMethods<CleanerInternal>
	& PublicAttributes
	& PublicMethods<CleanerInternal>
export type CleanerClass = {
	read new: () -> CleanerObject,
	read UseSignal: (SignalCn: () -> SignalLike<...any>) -> (),
}

return {}
