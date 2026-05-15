package info.jab.ms.controller;

import java.math.BigDecimal;
import java.util.Map;

import info.jab.ms.generated.api.CalculatorApi;
import info.jab.ms.generated.model.OperationRequest;
import info.jab.ms.generated.model.OperationResponse;
import info.jab.ms.service.CalculatorResult;
import info.jab.ms.service.CalculatorService;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class CalculatorController implements CalculatorApi {

	private final CalculatorService calculatorService;

	public CalculatorController(CalculatorService calculatorService) {
		this.calculatorService = calculatorService;
	}

	@Override
	public ResponseEntity<OperationResponse> sum(OperationRequest operationRequest) {
		return fromResult(calculatorService.sum(operationRequest.getOperator1(), operationRequest.getOperator2()));
	}

	@Override
	public ResponseEntity<OperationResponse> sub(OperationRequest operationRequest) {
		return fromResult(calculatorService.sub(operationRequest.getOperator1(), operationRequest.getOperator2()));
	}

	@Override
	public ResponseEntity<OperationResponse> mul(OperationRequest operationRequest) {
		return fromResult(calculatorService.mul(operationRequest.getOperator1(), operationRequest.getOperator2()));
	}

	@Override
	public ResponseEntity<OperationResponse> div(OperationRequest operationRequest) {
		return fromResult(calculatorService.div(operationRequest.getOperator1(), operationRequest.getOperator2()));
	}

	private static ResponseEntity<OperationResponse> fromResult(CalculatorResult result) {
		return switch (result) {
			case CalculatorResult.Ok(var value) -> ok(value);
			case CalculatorResult.Ko(var message) -> badRequest(message);
		};
	}

	private static ResponseEntity<OperationResponse> ok(BigDecimal result) {
		return ResponseEntity.ok(new OperationResponse(result));
	}

	@SuppressWarnings({ "rawtypes", "unchecked" })
	private static ResponseEntity<OperationResponse> badRequest(String message) {
		return (ResponseEntity) ResponseEntity.badRequest().body(Map.of("message", message));
	}

}
