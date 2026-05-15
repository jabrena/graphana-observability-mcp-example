package info.jab.ms.service;

import java.math.BigDecimal;

public sealed interface CalculatorResult permits CalculatorResult.Ok, CalculatorResult.Ko {

	record Ok(BigDecimal value) implements CalculatorResult { }

	record Ko(String message) implements CalculatorResult {
		public static Ko divisionByZero() {
			return new Ko("operator2 must not be zero");
		}
	}
}
