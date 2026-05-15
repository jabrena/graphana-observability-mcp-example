package info.jab.ms.service;

import java.math.BigDecimal;
import java.math.RoundingMode;

import org.springframework.stereotype.Service;

@Service
public class CalculatorService {

	private static final int SCALE = 10;

	public CalculatorResult sum(BigDecimal operator1, BigDecimal operator2) {
		return new CalculatorResult.Ok(operator1.add(operator2));
	}

	public CalculatorResult sub(BigDecimal operator1, BigDecimal operator2) {
		return new CalculatorResult.Ok(operator1.subtract(operator2));
	}

	public CalculatorResult mul(BigDecimal operator1, BigDecimal operator2) {
		return new CalculatorResult.Ok(operator1.multiply(operator2));
	}

	public CalculatorResult div(BigDecimal operator1, BigDecimal operator2) {
		if (operator2.compareTo(BigDecimal.ZERO) == 0) {
			return CalculatorResult.Ko.divisionByZero();
		}
		return new CalculatorResult.Ok(operator1.divide(operator2, SCALE, RoundingMode.HALF_UP));
	}
}
