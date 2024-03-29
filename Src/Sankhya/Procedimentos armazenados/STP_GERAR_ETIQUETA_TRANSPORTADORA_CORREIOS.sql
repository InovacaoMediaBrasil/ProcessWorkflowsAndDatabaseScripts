USE [SANKHYA_PRODUCAO]
GO
/****** Object:  StoredProcedure [sankhya].[STP_GERAR_ETIQUETA_TRANSPORTADORA_CORREIOS]    Script Date: 17/11/2017 16:54:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Guilherme Branco Stracini
-- Create date: 2017-10-10
-- Description:	Gera etiqueta padrão Correios de acordo com a tabela AD_EXPEDICAO
-- =============================================
ALTER PROCEDURE [sankhya].[STP_GERAR_ETIQUETA_TRANSPORTADORA_CORREIOS] 
	-- Add the parameters for the stored procedure here
	@CODMODTRANSP INT, 
	@CODENVIO CHAR(13) OUTPUT
AS
DECLARE
@NUMETIQ		VARCHAR(8),
@DIGETIQ		INT,
@SOMA			NUMERIC(15,2),
@RESTO			NUMERIC(15,2),
@TIPSERV		VARCHAR(10),
@NUMINIC		VARCHAR(50),
@NUMFIM			VARCHAR(50),
@SUBJECT		VARCHAR(100)
BEGIN
	SET NOCOUNT ON;

	/*
	 * Obtem a próxima etique da AD_EXPEDICAO para a modalidade de envio
	 */
	SELECT	@TIPSERV =		TIPSERV,  
			@NUMETIQ =		ISNULL(PROXNUM, NUMINIC) + 1,
			@NUMINIC =		NUMINIC, 
			@NUMFIM =		NUMFIM
	FROM AD_EXPEDICAO WITH (NOLOCK)
	WHERE IDMOD = @CODMODTRANSP 
	AND SEQATUAL = 'S';

	/* 
	 *	Verifica se existe uma etiqueta válida para o serviço selecionado, 
	 *	caso não exista lança erro e rollback se não for chamado do Sankhya
	 */
	IF @TIPSERV IS NULL 
	OR @NUMETIQ IS NULL
	OR CONVERT(INT, @NUMETIQ) < CONVERT(INT, @NUMINIC) 
	OR CONVERT(INT, @NUMETIQ) > CONVERT(INT, @NUMFIM)
	BEGIN 
		
		/*
		 * Não existe etiqueta disponível 
		 * Se não existir uma linha com SEQATUAL = 'S' então @TIPSERV será nulo e 
		 * por isso precisa ser populado aqui para não gerar erro
		 */
		IF @TIPSERV IS NULL 
			SELECT TOP 1 @TIPSERV = TIPSERV 
			FROM sankhya.AD_EXPEDICAO WITH (NOLOCK) 
			WHERE IDMOD = @CODMODTRANSP; 
										
		/*
		 * Envia um e-mail para o HELP abrindo um chamado para a TI verficar porque não tem etiqueta e não possível gerar
		 */
			
		SET @SUBJECT = 'Range de etiquetas (Correios) do serviço ' + @TIPSERV + ' acabou!';
			
		ROLLBACK;

		EXEC msdb.dbo.sp_send_dbmail
		@profile_name = 'SQLAlerts',
		@from_address = 'suporte@editorainovacao.com.br',
		@recipients = 'help@editorainovacao.com.br;devops@editorainovacao.com.br;',
		@body = @SUBJECT,
		@subject = @SUBJECT;

		COMMIT;

		RAISERROR('O range de etiquetas do serviço %s (Correios) acabou! Foi aberto um chamado para o departamento de TI!', 16, 1, @TIPSERV);
		RETURN NULL;
	END

	/*
	 * Existe etiqueta válida
	 *
	 *	Formação da etiqueta
	 *	2 letras - código do serviço escolhido (SU, DH, SW, DL, SX, etc)
	 *	8 números - identificação da etiqueta (sequencial, AD_EXPEDICAO)
	 *	1 número - digito verificador (fórmula)
	 *	2 letras - código do pais de origem (fixo: BR)
	 *	= 13 digitos
	 */

	/* 
	 * Número da etiqueta deve possuir 8 dígitos 
	 */
	SET @NUMETIQ= RIGHT('00000000' + @NUMETIQ, 8)
			
	/* 
	 * Gera dígito da etiqueta baseado em fórmula 
	 */
	SET @SOMA = SUBSTRING(@NUMETIQ, 1, 1) * 8 +
				SUBSTRING(@NUMETIQ, 2, 1) * 6 +
				SUBSTRING(@NUMETIQ, 3, 1) * 4 +
				SUBSTRING(@NUMETIQ, 4, 1) * 2 +
				SUBSTRING(@NUMETIQ, 5, 1) * 3 +
				SUBSTRING(@NUMETIQ, 6, 1) * 5 +
				SUBSTRING(@NUMETIQ, 7, 1) * 9 +
				SUBSTRING(@NUMETIQ, 8, 1) * 7;
	
	/*
	 * Calcula o resto da divisão de @SOMA por 11
	 */
	SET @RESTO = @SOMA % 11;
	
	/*
	 * Se o resto for 0 então o dígito é 5
	 * Se for 1 então o dígito é 0
	 * Em outros casos, é 11 - resto, que será um número entre 1 e 9
	 */

	SELECT @DIGETIQ = CASE @RESTO 
		WHEN 0 THEN 5
		WHEN 1 THEN 0
		ELSE 11 - @RESTO END;

	/*
	 * Associa o valor completo da etiqueta a variável CODENVIO para retorno do procedimento e utilização abaixo
	 */
	SET @CODENVIO = @TIPSERV + @NUMETIQ + CAST(@DIGETIQ AS VARCHAR) + 'BR';
		
	/* 
	 * Atualiza tabela de etiquetas (AD_EXPEDICAO) informando que a numeração foi utilizada 
	 */
	UPDATE AD_EXPEDICAO 
	SET PROXNUM =	@NUMETIQ, 
		SALDO =		(CONVERT(INT, NUMFIM) - CONVERT(INT, @NUMETIQ) + 1)
	WHERE IDMOD = @CODMODTRANSP 
	AND SEQATUAL = 'S';
END
