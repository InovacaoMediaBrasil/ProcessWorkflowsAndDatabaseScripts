USE [SANKHYA_PRODUCAO]
GO
/****** Object:  StoredProcedure [sankhya].[STP_GERAR_ETIQUETA_TRANSPORTADORA]    Script Date: 06/04/2018 12:21:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*	=============================================
	Author:			Guilherme Branco Stracini
	Create date:	2017-10-10
	Description:	Cria etiqueta (AD_CPENVIOS) para os pedidos com transportadora sendo Correios, Mandaê ou Mercado Livre/Envios

	Author:			Guilherme Branco Stracini
	Change date:	2018-03-28
	Description:	Verfica se existe algum envio com o status C na AD_CPENVIOS para o mesmo pedido, caso exista tenta reutilizar
					os dados caso ainda não tenha sido realizado					

	=============================================*/
ALTER PROCEDURE [sankhya].[STP_GERAR_ETIQUETA_TRANSPORTADORA]
	-- Add the parameters for the stored procedure here
	@NUNOTA INT, 
	@PEDORIGINAL INT,
	@ORDERID VARCHAR(100),
	@CODMODTRANSP INT
AS
DECLARE
@CODENVIO	VARCHAR(13),
@OS			VARCHAR(50),
@MATRIX		CHAR(160),
@TRACKER	CHAR(1),
@DELETAR	INT
BEGIN
	SET NOCOUNT ON;

	SET @OS = NULL;
	SET @MATRIX = NULL;
	SET @DELETAR = 0;

	/*
	 *	Entrega digital convertido para Mandaê - Economico
	 *	Pedidos da VTEX que possuem curso online e outros produtos entram como
	 *  entrega digital no sistema e por isso precisam ser alterados para uma transportadora real
	 */
	IF @CODMODTRANSP = 7
		SET @CODMODTRANSP = 10;
	
	/*
	 * Verifica se já existe uma numeração que possa ter sido cancelada e então reutiliza ela
	 */
	IF EXISTS(
		SELECT 1 
		FROM AD_CPENVIOS WITH (NOLOCK)
		WHERE PEDORIGINAL = @PEDORIGINAL 
		AND [STATUS] = 'C' 
		AND CODENVIO NOT IN (
			SELECT CODENVIO
			FROM AD_CPENVIOS WITH (NOLOCK)
			WHERE PEDORIGINAL = @PEDORIGINAL
			AND [STATUS] != 'C'
		)
	)
		SELECT @CODENVIO =	E.CODENVIO,
			   @OS =		E.OS
		FROM AD_CPENVIOS AS E WITH (NOLOCK)
		WHERE E.PEDORIGINAL = @PEDORIGINAL 
		AND E.[STATUS] = 'C' 
		AND E.CODENVIO NOT IN (
			SELECT CODENVIO
			FROM AD_CPENVIOS WITH (NOLOCK)
			WHERE PEDORIGINAL = @PEDORIGINAL
			AND [STATUS] != 'C'
		)
	
	/*
	 * Se for a modalidade 10 ou 11 (Mandaê) gera o código de rastreio conforme padrão pré estabelecido
	 * O padrão é: VTR0000000000 (VTR + 10 dígitos), onde os digitos devem ser o número único da nota
	 * com padding zero a esquerda
	 */
	ELSE IF @CODMODTRANSP IN (10, 11)
		SET @CODENVIO = 'VTR' + RIGHT('0000000000' + CAST(@NUNOTA AS VARCHAR), 10);	

	/*
	 * Se a modalidade de envio for Mercado Envios, e existir uma etiqueta do pedido registrado
	 * na tabela de etiquetas do Mercado Livre (AD_ETIQUETASMLB)
	 */
	ELSE IF EXISTS(SELECT 1 FROM AD_ETIQUETASMLB WITH (NOLOCK) WHERE PEDORIGINAL = @PEDORIGINAL)
		SELECT	@CODENVIO =	E.CODENVIO, 
				@OS =		E.PLP,
				@DELETAR =	1
		FROM sankhya.AD_ETIQUETASMLB AS E WITH (NOLOCK)
		WHERE PEDORIGINAL = @PEDORIGINAL;	

	/*
	 * Se a modalidade de envio for alguma existente na tabela de etiquetas dos Correios (AD_EXPEDICAO)
	 * Gera o código da etiqueta por lá
	 */
	ELSE IF EXISTS(SELECT 1 FROM sankhya.AD_EXPEDICAO WHERE IDMOD = @CODMODTRANSP)
		EXEC sankhya.STP_GERAR_ETIQUETA_TRANSPORTADORA_CORREIOS @CODMODTRANSP, @CODENVIO OUTPUT;	

	/*
	 * Outros casos não precisam de etiqueta, então termina a procedure
	 */
	ELSE
		RETURN;

	SET @TRACKER = 'M';
	
	IF @CODMODTRANSP NOT IN (10, 11)
	BEGIN
		SET @TRACKER = 'C';

		DECLARE 
			@CEP		CHAR(8),
			@SOMA		INT,
			@VAL		INT,
			@CODSERV	CHAR(5),
			@NUMEND		VARCHAR(5),
			@COMPL		CHAR(20),
			@VLR		FLOAT,
			@TEL		VARCHAR(15);

		SELECT	@CEP =		P.CEP,
				@NUMEND =	REPLACE(RTRIM(LTRIM(P.NUMEND)), 'S/N', '0'),
				@COMPL =	ISNULL(P.COMPLEMENTO, 0),
				@VLR =		C.VLRNOTA,
				@TEL =		P.TELEFONE
		FROM sankhya.TGFCAB AS C WITH (NOLOCK)
		INNER JOIN sankhya.TGFPAR AS P WITH (NOLOCK)
		ON C.CODPARC = P.CODPARC		
		WHERE C.NUNOTA = @NUNOTA;

		SELECT @CODSERV = T.CODVTEX
		FROM sankhya.AD_MODTRANSPORTE AS T WITH (NOLOCK)
		WHERE T.IDMOD = @CODMODTRANSP
		

		/*
		 * Se o CEP do parceiro não possuir 8 dígitos gera erro.
		 */
		IF LEN(@CEP) != 8
		BEGIN
			RAISERROR('O CEP do parceiro da nota %i precisa ter 8 dígitos!', 16, 1, @NUNOTA);
			RETURN;
		END		

		/*
		 * Soma os dígitos do CEP 
		 */
		SET @SOMA = CAST(SUBSTRING(@CEP, 1, 1) AS INT) +
					CAST(SUBSTRING(@CEP, 2, 1) AS INT) +
					CAST(SUBSTRING(@CEP, 3, 1) AS INT) +
					CAST(SUBSTRING(@CEP, 4, 1) AS INT) +
					CAST(SUBSTRING(@CEP, 5, 1) AS INT) +
					CAST(SUBSTRING(@CEP, 6, 1) AS INT) +
					CAST(SUBSTRING(@CEP, 7, 1) AS INT) +
					CAST(SUBSTRING(@CEP, 8, 1) AS INT);
		/*
		 * Seta o valor de @VAL como o resultado da subtração de 10 - o resultado do resto da soma divido por 10
		 */
		SET @VAL = 10 - (@SOMA % 10);
		
		/*
		 * Configura o valor da DataMatrix da etiqueta dos Correios
		 */
		SET @MATRIX =	@CEP + '00000' + '03137020' + '00000' + CAST(@VAL AS VARCHAR) + '51' + @CODENVIO + 
						'00000000' + RIGHT('0000000000' + ISNULL(@OS, ''), 10) + @CODSERV + '00' + 
						RIGHT('00000' + @NUMEND, 5) + RIGHT('                    ' + @COMPL, 20) + 
						RIGHT('00000' + LTRIM(STR(@VLR, 5, 0)),5) + RIGHT('000000000000' + @TEL, 12) + 
						'-00.000000' + '-00.000000' + '|' + '                             ';
	END

	/*
	 * Faz o INSERT na AD_CPENVIOS para que possa ser acompanhado pela Integração Service
	 */
	INSERT INTO sankhya.AD_CPENVIOS (PEDORIGINAL, ORDERID, NUNOTA, CODENVIO, OS, MATRIX, [STATUS], TRACKER, DTENVIO)
	VALUES (@PEDORIGINAL, @ORDERID, @NUNOTA, @CODENVIO, @OS, @MATRIX, 'N', @TRACKER, GETDATE());

	/*
	 * Se a flag de deletar estiver ativa, remove a etiqueta da tabela de etiquetas do Mercado Livre
	 */
	IF @DELETAR = 1
		DELETE FROM sankhya.AD_ETIQUETASMLB WHERE PEDORIGINAL = @PEDORIGINAL;
END
