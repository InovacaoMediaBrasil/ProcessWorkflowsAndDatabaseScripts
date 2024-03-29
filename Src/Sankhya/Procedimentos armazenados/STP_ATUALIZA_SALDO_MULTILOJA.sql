USE [SANKHYA_PRODUCAO]
GO
/****** Object:  StoredProcedure [sankhya].[STP_ATUALIZA_SALDO_MULTILOJA]    Script Date: 25/09/2018 15:06:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*	=============================================
	Author:			Rodrigo Lacalendola
	Author:			Guilherme Branco Stracini
	Create date:	2015-08-24
	Description:	Atualiza o campo ESTOQUE na tela Multiloja para todos os itens (Rodrigo)
 					Somente atualiza os itens que estão divergentes, (atualiza o campo ALTESTOQUE para entrar na fila da Integração) (Guilherme)

	Author:			Guilherme Branco Stracini
	Change date:	2018-09-25
	Description:	Adicionado WITH NOLOCK e usa casas decimais do cadastro do produto para arredondar o estoque

	============================================= */

ALTER PROCEDURE [sankhya].[STP_ATUALIZA_SALDO_MULTILOJA] (
       @P_CODUSU INT,                -- Código do usuário logado
       @P_IDSESSAO VARCHAR(4000),    -- Identificador da execução. Serve para buscar informações dos parâmetros/campos da execução.
       @P_QTDLINHAS INT,             -- Informa a quantidade de registros selecionados no momento da execução.
       @P_MENSAGEM VARCHAR(4000) OUT -- Caso seja passada uma mensagem aqui, ela será exibida como uma informação ao usuário.              
) AS
DECLARE
	   @CONTADOR INT,
	   @CODPROD INT,
	   @ESTOQUE DECIMAL(10,2),
	   @ESTOQUENOVO DECIMAL(10,2),
	   @CASASDECIMAIS INT
BEGIN
	
	SET @CONTADOR = 0;

	DECLARE cProdutos CURSOR LOCAL FOR 
    SELECT M.CODPROD, M.ESTOQUE, P.DECQTD
	FROM sankhya.AD_MULTILOJA AS M WITH (NOLOCK)
	INNER JOIN sankhya.TGFPRO AS P WITH (NOLOCK)
	ON M.CODPROD = P.CODPROD;

    OPEN cProdutos;

    FETCH NEXT FROM cProdutos
	INTO @CODPROD, @ESTOQUE, @CASASDECIMAIS;

    WHILE @@FETCH_STATUS = 0
    BEGIN

		SET @ESTOQUENOVO = ROUND(sankhya.FN_ESTOQUE_INOVACAO(@CODPROD), @CASASDECIMAIS);

		IF(@ESTOQUENOVO != @ESTOQUE)
	    BEGIN
		    UPDATE sankhya.AD_MULTILOJA SET ESTOQUE = @ESTOQUENOVO, ALTESTOQUE = 'S' WHERE CODPROD = @CODPROD;
			SET @CONTADOR = @CONTADOR + 1;
		END

		FETCH NEXT FROM cProdutos
		INTO @CODPROD, @ESTOQUE, @CASASDECIMAIS;
	END
	CLOSE cProdutos;
    DEALLOCATE cProdutos;
	SET @P_MENSAGEM = 'Saldo atualizado em ' + CAST(@CONTADOR AS VARCHAR) + ' produtos!';
END
