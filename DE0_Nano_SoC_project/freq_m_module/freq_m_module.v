module freq_m_module #(parameter n = 4)
(
	input reset,
	input clk_base, // опорная частота, по которой остчитывается промежуток времени (здесь 1с)
	input clk_in, // измеряемая частота
	input [2:0] freq_base, //регистр, содержащий значение опорной частоты. Если не требуется задавать извне, можно раскомментировать строку "parameter freq_base = ..."
	input [2:0] time_del,//регистр, содержащий значение делителя, на который сдвигается значение опорной частоты для уменьшения интервала измерения
	output reg [31:0] freq_mem, // регистр, сохраняющий измеренное значение частоты сигнала, подаваемого на вход freq_in
	output cout_i, // сигнал переполнения счётчика измеряемой частоты
	output reg cout_b // сигнал переполнения счётчика опорной частоты
);

/*модуль freq_m - частотомер, измеряет частоту, поступающую на линию clk_in.
Измеренное значение раз в секунду возвращается через регистр freq_mem.
Сигнал смены значения соответствует сигналу cout_b.
Сигнал cout_i служит для отслеживания переполнения счётчика измеряемой частоты.

Исходя из размерности счётчика (32 бита), максимальная измеряемая частота (2^32 - 1) Гц = 4_294_967_295 Гц
Если предполагается измерение больших частот, необходимо использовать сигнал cout_i
для отслеживания перехода счётчика через 0.

Размерность счётчика опорной частоты такая же, следовательно, максимальное значение
опорной частоты такое же.

*/


wire [31:0] freq_b, freq_i; // шины для передачи результатов работы счётчиков

reg sclr_b = 0, aclr_i = 0;

wire cout_b_base, cout_b_0, cout_b_1;

reg [31:0] freq_base_reg, time_del_reg;

assign freq_base_reg = freq_base[0] ? 'd100_000_000 : 'd400_000_000;
assign time_del_reg = time_del;

//assign cout_b = cout_b_0 || cout_b_1;

/* sclr_b - сигнал синхронного сброса счётчика опорной частоты
	aclr_i - сигнал асинхронного сброса счётчика измеряемой частоты*/

//parameter freq_base = 31'd200_000_000; // параметр, определяющий значение опорной частоты (необходимо задать перед использованием)

initial
begin
	
	cout_b = 0;//инициализация cout_b
	
end

// блок для формирования сигналов cout_b, sclr_b, aclr_i
always @(posedge clk_base)
begin
	
	/*сигнал cout_b становится в 1, если счётчик опорной частоты досчитывает до значения ((freq_base  >> time_del) - 1)*/
/*	if (freq_b == (freq_base_reg >> time_del_reg) - 1) cout_b_base <= 1;
	else cout_b_base <= 0;*/

	/* при достижении счётчиком опорной частоты значения (freq_base >> time_del) счётчики
	опорной и измеряемой частоты сбрасываются в 0 при помощи сигналов sclr_b и aclr_i*/
//	if (freq_b == (freq_base_reg >> time_del_reg))
	if (cout_b_base)
	begin
	
		sclr_b <= 1;
		aclr_i <= 1;
		
	end
	// после сброса счётчиков сигналы sclr_b и aclr_i устанавливаются обратно в 0	
	if (freq_b == 1'b0)
	begin
	
		sclr_b <= 0;
		aclr_i <= 0;
		
	end
	
end

cout_b_gen #(4) cout_gen0
(
	
	.clk(clk_base),
	.reset(reset),
	.freq_b(freq_b),
	.freq_base(freq_base_reg),
	.time_del(time_del_reg),
	.cout_b(cout_b)
	
);

/*cout_b_gen #(1) cout_gen1
(
	
	.clk(clk_base),
	.reset(reset),
	.freq_b(freq_b),
	.freq_base(freq_base_reg >> 1),
	.time_del(time_del_reg),
	.cout_b(cout_b_1)
	
);*/

cout_b_gen #(1) cout_gen_base
(
	
	.clk(clk_base),
	.reset(reset),
	.freq_b(freq_b),
	.freq_base(freq_base_reg),
	.time_del(time_del_reg),
	.cout_b(cout_b_base)
	
);

//Счётчик опорной частоты

Counter b_c
(
	
	.aclr(reset),
	.clock(clk_base),
	.sclr(sclr_b),
	.q(freq_b)
	
);

//Счётчик измеряемой частоты

Counter i_c
(
	
	.aclr(aclr_i || reset),
	.clock(clk_in),
	.sclr(1'b0),
	.cout(cout_i),
	.q(freq_i)
	
);


/* при установке сигнала cout_b в 1 значение измеряемой частоты (сдвинутое на делитель) 
сохраняется в выходном регистре freq_mem*/
always @(negedge cout_b_base)
begin
	
	freq_mem = freq_i << time_del_reg;
	
end

endmodule 