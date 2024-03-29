USE [SANKHYA_PRODUCAO]
GO
/****** Object:  StoredProcedure [sankhya].[STP_MARCAR_PED_CORRIGIDO_VTEX]    Script Date: 07/04/2017 20:17:18 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Guilherme Branco Stracini
-- Create date: 2016-12-05
-- Description:	Marca um pedido pendente de importação como corrigido para entrar novamente na fila de importação
-- =============================================
ALTER PROCEDURE [sankhya].[STP_MARCAR_PED_CORRIGIDO_VTEX] (
        @P_CODUSU INT,                -- Código do usuário logado
       @P_IDSESSAO VARCHAR(4000),    -- Identificador da execução. Serve para buscar informações dos parâmetros/campos da execução.
       @P_QTDLINHAS INT,             -- Informa a quantidade de registros selecionados no momento da execução.
       @P_MENSAGEM VARCHAR(4000) OUT -- Caso seja passada uma mensagem aqui, ela será exibida como uma informação ao usuário.
) AS
DECLARE
       @FIELD_CODPED INT,
       @I INT
BEGIN
	SET @I = 1
    WHILE @I <= @P_QTDLINHAS
    BEGIN
		SET @FIELD_CODPED = SANKHYA.ACT_INT_FIELD(@P_IDSESSAO, @I, 'CODPED')
		IF NOT EXISTS(SELECT 1 FROM sankhya.AD_IMPORTACAOPEDPENDENTE WHERE [CODPED] = @FIELD_CODPED AND [STATUS] = 'E')
			RAISERROR('O pedido %i não está pendente de correção', 16, 1, @FIELD_CODPED);				
		UPDATE sankhya.AD_IMPORTACAOPEDPENDENTE 
		SET [STATUS] = 'A', [CODUSU] = @P_CODUSU 
		WHERE [CODPED] = @FIELD_CODPED AND STATUS = 'E';
        SET @I = @I + 1
	END
END
