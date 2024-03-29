USE [SANKHYA_PRODUCAO]
GO
/****** Object:  StoredProcedure [sankhya].[STP_IMP_PED_VP]    Script Date: 27/09/2018 16:18:06 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Guilherme Branco Stracini
-- Create date: 2018-09-26
-- Description:	Realiza a importação de um pedido pelo Visualizador de Pedidos
-- =============================================
ALTER PROCEDURE [sankhya].[STP_IMP_PED_VP] (
       @CODPED INT,
	   @USUARIO VARCHAR(30),   
       @MENSAGEM VARCHAR(4000) OUT
) AS
DECLARE
	@NUNOTA INT,
	@CODUSU INT,
	@CODPARC INT,
	@CODLOJA INT,
	@CODVEND INT,
	@CDEMPRESA VARCHAR(20),
	@CDREPRESENTANTE VARCHAR(20),
	@FLORIGEMPEDIDOAUX CHAR(1),
	@DTPEDIDO DATETIME;
BEGIN   
	SELECT @CODLOJA = P.CODLOJA, @CODPARC = P.CODPARC, @CODVEND = P.CODVEND
	FROM sankhya.AD_PEDIDOVTEXSC AS P WITH (NOLOCK)
	WHERE PEDORIGINAL = @CODPED;

	IF @CODLOJA IS NULL
	BEGIN
		RAISERROR('O pedido %i não existe na tela Controle de Pedidos, não é possível realizar a operação pelo Visualizador de Pedidos!', 16, 1, @CODPED);
		RETURN;
	END

	SELECT TOP 1 @DTPEDIDO = ISNULL(F.DATA, GETDATE())
	FROM sankhya.AD_PEDIDOVTEXSCFLUXO AS F WITH (NOLOCK)
	WHERE F.PEDORIGINAL = @CODPED
	AND F.OCORRENCIA = 'P';
	
	SELECT @CODUSU = U.CODUSU
	FROM sankhya.TSIUSU AS U WITH (NOLOCK)
	WHERE U.NOMEUSU = @USUARIO;

	IF @CODLOJA > 0
	BEGIN
	    IF EXISTS (SELECT 1 FROM sankhya.AD_IMPORTACAOPEDPENDENTE WHERE CODPED = @CODPED)
		BEGIN
			RAISERROR('O pedido %i já está na fila de importação, aguarde até que a importação seja realizada!', 16, 1, @CODPED);
			RETURN;
		END
		INSERT INTO sankhya.AD_IMPORTACAOPEDPENDENTE (CODPED, STATUS, CODUSU, CODPARC, CODVEND, DTPEDIDO, DTALTER, DTIMPORTACAO) VALUES (@CODPED, 'M', @CODUSU, @CODPARC, @CODVEND, @DTPEDIDO, GETDATE(), GETDATE());  
		SET @MENSAGEM = 'Pedido ' + CAST(@CODPED AS VARCHAR) + ' adicionado a fila de importação, a importação da VTEX ocorre de hora em hora durante o horário comercial!';
	END
	ELSE
	BEGIN
		IF EXISTS (SELECT 1 FROM sankhya.TGFCAB WITH (NOLOCK) WHERE AD_PEDORIGINAL = @CODPED)
		BEGIN
			RAISERROR('O pedido %i já se encontra no Sankhya, por favor cancele-o primeiro pelo Portal de Vendas para realizar a reimportação', 16, 1, @CODPED);
			RETURN;
		END
		IF NOT EXISTS(SELECT 1 FROM EDITORAWVWEBPRD.dbo.TBLVWPEDIDO WITH (NOLOCK) WHERE NUPEDIDO = @CODPED)
		BEGIN
			RAISERROR('O pedido %i não foi localizado no WMW Vendas!', 16, 1, @CODPED);
			RETURN;
		END
		UPDATE EDITORAWVWEBPRD.dbo.TBLVWPEDIDO
		SET 
			dsMensagemControleErp = NULL,
			DtEnvioErp = NULL,
			flControleErp = NULL,
			HrEnvioErp = NULL,
			CDSTATUSPEDIDO = 2
		WHERE NUPEDIDO = @CODPED;

		SELECT	@CDEMPRESA = CDEMPRESA,
				@CDREPRESENTANTE = CDREPRESENTANTE,
				@FLORIGEMPEDIDOAUX = FLORIGEMPEDIDO
		FROM EDITORAWVWEBPRD.dbo.TBLVWPEDIDO WITH (NOLOCK)
		WHERE NUPEDIDO = @CODPED;

		EXEC EDITORAWVWEBPRD.dbo.PRIMPORTAPEDIDOS
		@CDEMPRESA = @CDEMPRESA, 
		@CDREPRESENTANTE = @CDREPRESENTANTE,
		@FLORIGEMPEDIDOAUX = @FLORIGEMPEDIDOAUX,
		@NUPEDIDOAUX = @CODPED,
		@RETORNO = OUTPUT;

		SELECT @NUNOTA = NUNOTA
		FROM sankhya.TGFCAB WITH (NOLOCK)
		WHERE AD_PEDORIGINAL = @CODPED;

		SET @MENSAGEM = 'Pedido ' + CAST(@CODPED AS VARCHAR) + ' reimportado com sucesso! Novo número único: ' + CAST(@NUNOTA AS VARCHAR);
	END	
END