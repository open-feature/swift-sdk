extension Features {
    // MARK: Boolean
    public func getBooleanValue(key: String, defaultValue: Bool) -> Bool {
        getValue(key: key, defaultValue: defaultValue)
    }

    public func getBooleanValue(
        key: String, defaultValue: Bool, options: FlagEvaluationOptions
    ) -> Bool {
        getValue(key: key, defaultValue: defaultValue, options: options)
    }

    public func getBooleanDetails(key: String, defaultValue: Bool) -> FlagEvaluationDetails<Bool> {
        getDetails(key: key, defaultValue: defaultValue, options: FlagEvaluationOptions())
    }

    public func getBooleanDetails(
        key: String, defaultValue: Bool, options: FlagEvaluationOptions
    ) -> FlagEvaluationDetails<Bool> {
        getDetails(key: key, defaultValue: defaultValue, options: options)
    }
}

extension Features {
    // MARK: String
    public func getStringValue(key: String, defaultValue: String) -> String {
        getValue(key: key, defaultValue: defaultValue)
    }

    public func getStringValue(
        key: String, defaultValue: String, options: FlagEvaluationOptions
    ) -> String {
        getValue(key: key, defaultValue: defaultValue, options: options)
    }

    public func getStringDetails(key: String, defaultValue: String) -> FlagEvaluationDetails<String> {
        getDetails(key: key, defaultValue: defaultValue, options: FlagEvaluationOptions())
    }

    public func getStringDetails(
        key: String, defaultValue: String, options: FlagEvaluationOptions
    ) -> FlagEvaluationDetails<String> {
        getDetails(key: key, defaultValue: defaultValue, options: options)
    }
}

extension Features {
    // MARK: Integer
    public func getIntegerValue(key: String, defaultValue: Int64) -> Int64 {
        getValue(key: key, defaultValue: defaultValue)
    }

    public func getIntegerValue(
        key: String, defaultValue: Int64, options: FlagEvaluationOptions
    ) -> Int64 {
        getValue(key: key, defaultValue: defaultValue, options: options)
    }

    public func getIntegerDetails(key: String, defaultValue: Int64) -> FlagEvaluationDetails<Int64> {
        getDetails(key: key, defaultValue: defaultValue, options: FlagEvaluationOptions())
    }

    public func getIntegerDetails(
        key: String, defaultValue: Int64, options: FlagEvaluationOptions
    ) -> FlagEvaluationDetails<Int64> {
        getDetails(key: key, defaultValue: defaultValue, options: options)
    }
}

extension Features {
    // MARK: Double
    public func getDoubleValue(key: String, defaultValue: Double) -> Double {
        getValue(key: key, defaultValue: defaultValue)
    }

    public func getDoubleValue(
        key: String, defaultValue: Double, options: FlagEvaluationOptions
    ) -> Double {
        getValue(key: key, defaultValue: defaultValue, options: options)
    }

    public func getDoubleDetails(key: String, defaultValue: Double) -> FlagEvaluationDetails<Double> {
        getDetails(key: key, defaultValue: defaultValue, options: FlagEvaluationOptions())
    }

    public func getDoubleDetails(
        key: String, defaultValue: Double, options: FlagEvaluationOptions
    ) -> FlagEvaluationDetails<Double> {
        getDetails(key: key, defaultValue: defaultValue, options: options)
    }
}

extension Features {
    // MARK: Object
    public func getObjectValue(key: String, defaultValue: Value) -> Value {
        getValue(key: key, defaultValue: defaultValue)
    }

    public func getObjectValue(
        key: String, defaultValue: Value, options: FlagEvaluationOptions
    ) -> Value {
        getValue(key: key, defaultValue: defaultValue, options: options)
    }

    public func getObjectDetails(key: String, defaultValue: Value) -> FlagEvaluationDetails<Value> {
        getDetails(key: key, defaultValue: defaultValue, options: FlagEvaluationOptions())
    }

    public func getObjectDetails(
        key: String, defaultValue: Value, options: FlagEvaluationOptions
    ) -> FlagEvaluationDetails<Value> {
        getDetails(key: key, defaultValue: defaultValue, options: options)
    }
}
