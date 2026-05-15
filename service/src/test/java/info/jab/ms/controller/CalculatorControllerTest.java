package info.jab.ms.controller;

import java.math.BigDecimal;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import info.jab.ms.service.CalculatorResult;
import info.jab.ms.service.CalculatorService;

@WebMvcTest(CalculatorController.class)
class CalculatorControllerTest {

	@Autowired
	private MockMvc mockMvc;

	@MockitoBean
	private CalculatorService calculatorService;

	@Test
	void sumReturnsResult() throws Exception {
		Mockito.when(calculatorService.sum(new BigDecimal("10.0"), new BigDecimal("2.0")))
			.thenReturn(new CalculatorResult.Ok(new BigDecimal("12.0")));

		mockMvc.perform(post("/api/v1/sum")
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"operator1": 10.0, "operator2": 2.0}
						"""))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.result").value(12.0));
	}

	@Test
	void subReturnsResult() throws Exception {
		Mockito.when(calculatorService.sub(new BigDecimal("10.0"), new BigDecimal("2.0")))
			.thenReturn(new CalculatorResult.Ok(new BigDecimal("8.0")));

		mockMvc.perform(post("/api/v1/sub")
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"operator1": 10.0, "operator2": 2.0}
						"""))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.result").value(8.0));
	}

	@Test
	void mulReturnsResult() throws Exception {
		Mockito.when(calculatorService.mul(new BigDecimal("10.0"), new BigDecimal("2.0")))
			.thenReturn(new CalculatorResult.Ok(new BigDecimal("20.0")));

		mockMvc.perform(post("/api/v1/mul")
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"operator1": 10.0, "operator2": 2.0}
						"""))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.result").value(20.0));
	}

	@Test
	void divReturnsResult() throws Exception {
		Mockito.when(calculatorService.div(new BigDecimal("10.0"), new BigDecimal("2.0")))
			.thenReturn(new CalculatorResult.Ok(new BigDecimal("5.0")));

		mockMvc.perform(post("/api/v1/div")
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"operator1": 10.0, "operator2": 2.0}
						"""))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.result").value(5.0));
	}

}
