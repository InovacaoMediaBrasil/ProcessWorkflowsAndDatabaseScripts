USE [SANKHYA_PRODUCAO]
GO
/****** Object:  UserDefinedFunction [sankhya].[FN_VALOR_VENDA_COMPONENTE_KIT]    Script Date: 15/03/2018 10:47:21 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* =============================================
	Author:			Guilherme Branco Stracini
	Create date:	2017-09-29
	Description:	Retorna o valor de venda de um componente de um kit para um pedido
					Caso o código do componente seja
					O cálculo é feito baseado na data do pedido original


	Author:			Rodrigo Lacalendola
	Change date:	2017-12-12
	Description:	Considerando agora se o valor calculado do kit for diferente do inserido no pedido original,
					é mantido o valor usado no pedido original.	

	Author:			Guilherme Branco Stracini
	Change date:	2018-01-30
	Description:	Devido a existência de KITs com Curso Online, o preço do KIT precisa ser calculado corretamente 
					sem o(s) curso(s) online a partir das notas da TOP 505 (expedição - TIPMOV P - porém pedidos também são P), 
					venda (550 - TIPMOV V) e possíveis devoluções (600, 601, 602 - TIPMOV D)
	

 ============================================= */
ALTER FUNCTION [sankhya].[FN_VALOR_VENDA_COMPONENTE_KIT]
(
	@CODMATPRIMA	INT,
	@CODKIT			INT,
	@NUNOTA			INT,
	@VALORKIT		FLOAT
)
RETURNS FLOAT
AS
BEGIN
	DECLARE @VALOR				FLOAT,
			@VALORKITINICIAL	FLOAT,
			@DATAPEDIDO			DATETIME,
			@DATACADASTRO		DATETIME,
			@CODTIPOPER			INT,
			@TIPMOV				CHAR;


	/*
	 * Valida se a NUNOTA e o CODKIT são maiores que 0, se não forem retorna nulo.
	 */
	IF @NUNOTA IS NULL OR @NUNOTA <= 0 OR @CODKIT IS NULL OR @CODKIT <= 0
		RETURN NULL;	

	/*
	 * Seleciona a data do pedido pela AD_PEDIDOVTEXSCFLUXO na ocorrência P
	 * pegando o pedido original na TGFCAB para a NUNOTA informada no parâmetro
	 */
	SELECT		@DATAPEDIDO = F.DATA,
				@CODTIPOPER = C.CODTIPOPER,
				@TIPMOV =	  C.TIPMOV
	FROM		sankhya.TGFCAB AS C WITH (NOLOCK)
	INNER JOIN  sankhya.AD_PEDIDOVTEXSCFLUXO AS F  WITH (NOLOCK)
	ON			F.PEDORIGINAL = C.AD_PEDORIGINAL
	WHERE		C.NUNOTA = @NUNOTA 
	AND			OCORRENCIA = 'P';

	/*
	 * Se for pedido da VTEX (Integração Service), ele só é cadastrado na controle de pedidos após completar a integração
	 * por este motivo não irá existir o fluxo e a variavel DATAPEDIDO será nula, então será feito o processo inverso,
	 * será obtido o valor que foi inserido no KIT e então pega-se a data de precificação que tem esse valor
	 */
	IF @DATAPEDIDO IS NULL OR @DATAPEDIDO = ''
		SELECT @DATAPEDIDO = MAX(S.DTCADASTRO)
		FROM (
			SELECT	CAST(SUM(VLRVENDA) AS MONEY) AS VLRVENDA,
					DTCADASTRO
			FROM sankhya.AD_TGFICPHIST WITH (NOLOCK)
			WHERE CODPROD = @CODKIT
			GROUP BY DTCADASTRO
		) AS S
		WHERE S.VLRVENDA = CAST(@VALORKIT AS MONEY)
			
	/*
	 * Seleciona a última precificação antes da data do pedido
	 * Este campo pode retornar NULL para pedidos antigos, 
	 * neste caso será retornado o primeiro preço disponível na verificação abaixo
	 */
	SELECT TOP 1 @DATACADASTRO = MAX(H.DTCADASTRO)
	FROM	sankhya.AD_TGFICPHIST AS H WITH (NOLOCK)
	WHERE	H.CODPROD = @CODKIT
	AND		H.DTCADASTRO <= @DATAPEDIDO
	GROUP BY H.DTCADASTRO
	HAVING CAST(SUM(VLRVENDA) AS MONEY) = @VALORKIT
	AND COUNT(CODMATPRIMA) = (SELECT COUNT(CODMATPRIMA) FROM sankhya.TGFICP WITH (NOLOCK) WHERE CODPROD = @CODKIT)
	ORDER BY DTCADASTRO DESC;

	/*
	 * Verifica o preço registrado no movimento de PEDIDO (500,501,502,503,515,520)
	 */

	 SELECT @VALORKITINICIAL = SUM(VLRTOT)/SUM(QTDNEG) FROM sankhya.TGFITE ITE WITH(NOLOCK)
	 INNER JOIN sankhya.TGFCAB CAB WITH(NOLOCK) ON CAB.NUNOTA = ITE.NUNOTA
	 WHERE ITE.CODPROD = @CODKIT 
	 AND ITE.CODVOL = 'KT' 
	 AND CAB.CODTIPOPER IN (500,501,502,503,515) 
	 AND AD_PEDORIGINAL = (SELECT TOP 1 AD_PEDORIGINAL FROM sankhya.TGFCAB WITH(NOLOCK) WHERE NUNOTA = @NUNOTA)

	 
	/*
	 * Se o valor inicial é diferente do valor calculado, será utilizado o inicial
	 */
	  IF @VALORKIT != @VALORKITINICIAL
				SET @DATACADASTRO = (SELECT	 TOP 1 MAX(DTCADASTRO)
									FROM	sankhya.AD_TGFICPHIST AS H WITH (NOLOCK)
									WHERE	H.CODPROD = @CODKIT AND DTCADASTRO <= @DATACADASTRO
									GROUP BY DTCADASTRO
									HAVING CAST(SUM(VLRVENDA) AS MONEY) = @VALORKITINICIAL
									ORDER BY DTCADASTRO DESC)
			
	/*
	 * Se por acaso a nota é anterior a criação da tela AD_TGFICPHIST
	 * Será retornado o primeiro valor disponível para aquele KIT
	 */
	IF @DATACADASTRO IS NULL
		SELECT	@DATACADASTRO = DTCADASTRO
		FROM	sankhya.AD_TGFICPHIST AS H WITH (NOLOCK)
		WHERE	H.CODPROD = @CODKIT;
	
		
	/*
	 * Se foi fornecido o código da matéria prima (componente)
	 * então será retornado o valor UNITÁRIO do componente
	 */
	IF @CODMATPRIMA > 0
		SELECT		@VALOR = H.VLRVENDA / I.QTDMISTURA
		FROM		sankhya.AD_TGFICPHIST AS H WITH (NOLOCK)
		INNER JOIN	sankhya.TGFICP I WITH (NOLOCK)
		ON			I.CODPROD = H.CODPROD 
		AND			I.CODMATPRIMA = H.CODMATPRIMA
		WHERE		H.CODMATPRIMA = @CODMATPRIMA
		AND			H.CODPROD = @CODKIT
		AND			H.DTCADASTRO = @DATACADASTRO;
	/*
	 * Caso contrário retornamos o valor do KIT completo
	 */	
	ELSE
		SELECT		@VALOR = SUM(H.VLRVENDA)
		FROM		sankhya.AD_TGFICPHIST AS H WITH (NOLOCK)
		INNER JOIN	sankhya.TGFICP I WITH (NOLOCK)
		ON			I.CODPROD = H.CODPROD 
		AND			I.CODMATPRIMA = H.CODMATPRIMA
		INNER JOIN	sankhya.TGFPRO AS P WITH (NOLOCK)
		ON			P.CODPROD = I.CODMATPRIMA
		WHERE		H.CODPROD = @CODKIT
		AND			H.DTCADASTRO = @DATACADASTRO
		AND			((@CODTIPOPER != 505 AND @TIPMOV NOT IN ('V', 'D')) OR P.CODGRUPOPROD != 720000);

	/*
	 * Se a nota é anterior a criação da tela AD_TGFICPHIST e não existe precificação do componente/KIT nela, 
	 * então pega da TGFICP os valores
	 */
	IF @VALOR IS NULL AND @CODMATPRIMA > 0
		SELECT	@VALOR = I.AD_VLRVENDA / I.QTDMISTURA
		FROM	sankhya.TGFICP AS I WITH (NOLOCK)
		WHERE	I.CODMATPRIMA = @CODMATPRIMA
		AND		I.CODPROD = @CODKIT;
	ELSE IF @VALOR IS NULL
		SELECT	@VALOR = SUM(I.AD_VLRVENDA)
		FROM	sankhya.TGFICP AS I WITH (NOLOCK)
		WHERE	I.CODPROD = @CODKIT;


		
		/*
		 * Caso seja um curso online, dentro de um KIT, verifica se está na TOP de expedição, venda ou devolução
		 * e ZERA o preço, para não atrapalhar o restante.
		 */
		IF (SELECT CODGRUPOPROD FROM sankhya.TGFPRO WITH(NOLOCK) WHERE CODPROD = @CODMATPRIMA) = 720000 AND @CODTIPOPER IN (505,550,561,600)
			SET @VALOR = 0


	/*
	 * Retorna o valor do componente ou do KIT para a nota informada
	 */
	RETURN @VALOR;
END
