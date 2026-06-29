--!strict
--!native
--!optimize 2
----- Typedef -----
local Typedef = require("@self/Typedef")

type SignalLike<T...> = Typedef.SignalLike<T...>
type Cleanable = Typedef.Cleanable
type CleanUpFunction = Typedef.CleanUpFunction
type Constructable<T, A...> = Typedef.Constructable<T, A...>

type PrivateMethods<self> = Typedef.PrivateMethods<self>
type PublicMethods<self> = Typedef.PublicMethods<self>

export type CleanerObject = Typedef.CleanerObject
type CleanerInternal = Typedef.CleanerInternal
type CleanerClass = Typedef.CleanerClass

----- CONFIG & varaiables -----
local DEFAULT_CLEAN_UP_METHODS = table.freeze({
	"Destroy",
	"Disconnect",
	"Close",
	"Stop",
})

local DEFAULT_SIGNAL_CONSTRUCTOR: () -> SignalLike<...any> = function()
	local callbacks = {}
	return {
		Connect = function(self, callback)
			callbacks[callback] = true
			return {
				Connected = true,
				Disconnect = function(self)
					self.Connected = false
					callbacks[callback] = nil
				end,
			}
		end,
		Once = function(self, callback)
			local cn
			cn = self:Connect(function(...)
				if cn then
					cn:Disconnect()
				end
				callback(...)
			end)
			return cn
		end,
		Wait = function(self)
			local thread = coroutine.running()
			local cn
			cn = self:Connect(function(...)
				if cn then
					cn:Disconnect()
				end
				task.spawn(thread, ...)
			end)
			return coroutine.yield()
		end,
		Fire = function(self, ...)
			for callback in callbacks do
				task.spawn(callback, ...)
			end
		end,
		Destroy = function(self)
			table.clear(callbacks)
		end,
	}
end

----- Helper functions -----
local function GetCleanUpFunctionFromObject(Obj: Cleanable, CleanUpMethod: string?, level: number): CleanUpFunction
	if not Obj then
		error(`Invalid object got nil`, level)
	end

	if typeof(Obj) == "function" then
		return Obj
	end

	if typeof(Obj) == "thread" then
		return function()
			local ok, result = pcall(coroutine.close, Obj)
			if not ok then
				warn(`[MiCleaner] Failed to close thread: {result}`)
			end
		end
	end

	if typeof(Obj) == "table" then
		if CleanUpMethod then
			local method = Obj[CleanUpMethod]
			if method and typeof(method) == "function" then
				return method
			end
			error(`Invalid clean up method for object`, level)
		end
		for _, name in DEFAULT_CLEAN_UP_METHODS do
			local method = Obj[name] or Obj[name:lower()]
			if method and typeof(method) == "function" then
				return method
			end
		end
		error(`Couldn't find a valid cleanup method on table object`, level)
	end

	if typeof(Obj) == "Instance" then
		return Obj.Destroy
	end
	if typeof(Obj) == "RBXScriptConnection" then
		return Obj.Disconnect
	end

	error(`Unsupported object type: {typeof(Obj)}`, level)
end

local function AssertSignalLike(obj: any)
	if
		typeof(obj) ~= "RBXScriptSignal"
		and (typeof(obj) ~= "table" or typeof(obj.Connect) ~= "function" or typeof(obj.Once) ~= "function")
	then
		error(`Invalid argument #1 (RBXScriptSignal or SignalLike expected, got {typeof(obj)})`, 3)
	end
end

----- Class -----
local MiCleaner: CleanerClass

local PrivateMethods: PrivateMethods<CleanerInternal> = {
	__CheckIfCleaning = function(self, methodName)
		if self._isCleaning then
			error(`called MiCleaner:{methodName} while cleaning`, 3)
		end
	end,

	__FindObjectIndex = function(self, obj)
		for i, entry in self._CleanEntries do
			if entry.Object == obj then
				return i
			end
		end
		return nil
	end,

	__FindAndCleanObject = function(self, obj)
		local CleanEntries = self._CleanEntries
		local index = self:__FindObjectIndex(obj)
		if index then
			local entry = CleanEntries[index]
			local last = #CleanEntries
			CleanEntries[index] = CleanEntries[last]
			CleanEntries[last] = nil
			entry.CleanUpFunction(entry.Object)
			return true
		end
		return false
	end,
}

local PublicMethods: PublicMethods<CleanerInternal> = {
	Add = function<T>(self, cleanable, cleanUpMethod): T
		self:__CheckIfCleaning(`Add`)
		table.insert(self._CleanEntries, {
			Object = cleanable,
			CleanUpFunction = GetCleanUpFunctionFromObject(cleanable, cleanUpMethod, 3),
		})
		return cleanable
	end,

	Clone = function<T>(self, inst): T
		self:__CheckIfCleaning(`Clone`)
		return self:Add(inst:Clone())
	end,

	Extend = function(self)
		self:__CheckIfCleaning(`Extend`)
		return self:Construct(MiCleaner, `Destroy`)
	end,

	Construct = function<T, A...>(self, class: Constructable<T, A...>, cleanUpMethod, ...)
		self:__CheckIfCleaning(`Construct`)
		local object = if typeof(class) == "table"
			then class.new(...)
			elseif typeof(class) == "function" then class(...)
			else error(`Invalid argument #1 to 'Cleaner:Construct' (got "{typeof(class)}")`, 2)
		return self:Add(object, cleanUpMethod)
	end,

	Constructer = function(self, class, cleanUpMethod)
		self:__CheckIfCleaning(`Constructer`)
		return function(...)
			return self:Construct(class, cleanUpMethod, ...)
		end
	end,

	Remove = function(self, cleanable)
		self:__CheckIfCleaning(`Remove`)
		if not self:__FindAndCleanObject(cleanable) then
			warn(`[MiCleaner] Object not found in cleaner, nothing was removed`)
		end
	end,

	Pop = function(self, cleanable)
		self:__CheckIfCleaning(`Pop`)
		local index = self:__FindObjectIndex(cleanable)
		if index then
			local CleanEntries = self._CleanEntries
			local last = #CleanEntries
			CleanEntries[index] = CleanEntries[last]
			CleanEntries[last] = nil
		else
			warn(`[MiCleaner] Object not found in cleaner`)
		end
	end,

	Connect = function(self, signal, callback)
		self:__CheckIfCleaning(`Connect`)
		AssertSignalLike(signal)
		local cn = (signal :: SignalLike<...any>):Connect(callback)
		table.insert(self._CleanEntries, {
			Object = cn,
			CleanUpFunction = GetCleanUpFunctionFromObject(cn, nil, 4),
		})
		return cn
	end,

	Once = function(self, signal, callback)
		self:__CheckIfCleaning(`Once`)
		AssertSignalLike(signal)
		local cn = (signal :: SignalLike<...any>):Once(callback)
		table.insert(self._CleanEntries, {
			Object = cn,
			CleanUpFunction = GetCleanUpFunctionFromObject(cn, nil, 4),
		})
		return cn
	end,

	Attach = function(self, inst)
		self:__CheckIfCleaning(`Attach`)
		if not inst:IsDescendantOf(game) then
			error(`Instance is not a descendant of game`, 2)
		end
		self:Once(inst.Destroying, function()
			self:Clean()
		end)
	end,

	Clean = function(self)
		if self._isDestroyed then
			return
		end
		self:__CheckIfCleaning(`Clean`)
		self._isCleaning = true

		for _, entry in self._CleanEntries do
			entry.CleanUpFunction(entry.Object)
		end
		table.clear(self._CleanEntries)

		self.OnClean:Fire()
		self._isCleaning = false
	end,

	Destroy = function(self)
		if self._isDestroyed then
			return
		end
		self._isDestroyed = true
		self:Clean()
		self.OnClean:Destroy()
	end,
}

MiCleaner = {
	new = function()
		local self: CleanerInternal = {

			OnClean = DEFAULT_SIGNAL_CONSTRUCTOR(),
			_CleanEntries = {},
			_isCleaning = false,
			_isDestroyed = false,

			Add = PublicMethods.Add,
			Clone = PublicMethods.Clone,
			Construct = PublicMethods.Construct,
			Constructer = PublicMethods.Constructer,
			Extend = PublicMethods.Extend,
			Remove = PublicMethods.Remove,
			Pop = PublicMethods.Pop,
			Connect = PublicMethods.Connect,
			Once = PublicMethods.Once,
			Attach = PublicMethods.Attach,
			Clean = PublicMethods.Clean,
			Destroy = PublicMethods.Destroy,

			__CheckIfCleaning = PrivateMethods.__CheckIfCleaning,
			__FindObjectIndex = PrivateMethods.__FindObjectIndex,
			__FindAndCleanObject = PrivateMethods.__FindAndCleanObject,
		}

		return self :: CleanerObject
	end,

	UseSignal = function(SignalCn: () -> SignalLike<...any>)
		-- TODO add runtime check
		DEFAULT_SIGNAL_CONSTRUCTOR = SignalCn
	end,
}

return MiCleaner
